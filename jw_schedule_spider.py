#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
重外院（强智教务）课表导出脚本

依赖：
    python -m pip install requests beautifulsoup4

运行：
    python jw_schedule_spider.py

脚本会在终端提示输入学号、密码和图片验证码。验证码需要人工识别，
不会保存账号密码，也不会尝试绕过验证码。
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import re
import sys
import time
import webbrowser
from datetime import datetime
from pathlib import Path
from typing import Any

import requests
from bs4 import BeautifulSoup

DEFAULT_BASE_URL = "https://jw.educationgroup.cn/cqwywsxy"
EDU_SUFFIX = "_jsxsd"

LOGIN_PAGE = "/"
CAPTCHA_PATH = "/verifycode.servlet"
SESSION_TOKEN_PATH = "/Logon.do?method=logon&flag=sess"
LOGIN_PATH = "/Logon.do?method=logon"
SCHEDULE_PATH = "/xskb/xskb_list.do"


def clean_text(value: str | None) -> str:
    """压缩 HTML 文本中的空白字符。"""
    value = (value or "").replace("\xa0", " ")
    return re.sub(r"\s+", " ", value).strip()


def encode_login_data(username: str, password: str, token: str) -> str:
    """复现登录页 JavaScript 中的 encoded 字段计算方式。"""
    if "#" not in token:
        raise RuntimeError(f"登录会话参数格式异常：{token[:100]!r}")

    scode, sxh = token.split("#", 1)
    raw = f"{username}%%%{password}"
    encoded_parts: list[str] = []

    for index, char in enumerate(raw):
        if index >= 20:
            encoded_parts.append(raw[index:])
            break
        prefix_len = int(sxh[index])
        encoded_parts.append(char)
        encoded_parts.append(scode[:prefix_len])
        scode = scode[prefix_len:]

    return "".join(encoded_parts)


class JwClient:
    def __init__(self, base_url: str = DEFAULT_BASE_URL, timeout: int = 30) -> None:
        self.base_url = base_url.rstrip("/")
        self.edu_url = self.base_url + EDU_SUFFIX
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/132.0.0.0 Safari/537.36"
                ),
                "Accept-Language": "zh-CN,zh;q=0.9",
            }
        )

    def login(self, username: str, password: str, open_captcha: bool = True) -> None:
        """登录教务系统。验证码由用户根据图片手动输入。"""
        self.session.get(self.base_url + LOGIN_PAGE, timeout=self.timeout).raise_for_status()
        last_message = ""

        for attempt in range(1, 6):
            captcha = self.session.get(
                self.base_url + CAPTCHA_PATH,
                params={"t": str(int(time.time() * 1000))},
                timeout=self.timeout,
            )
            captcha.raise_for_status()
            captcha_file = Path("captcha.png").resolve()
            captcha_file.write_bytes(captcha.content)

            print(f"\n第 {attempt} 次验证码：{captcha_file}")
            if open_captcha:
                webbrowser.open(captcha_file.as_uri())
            else:
                print("请手动打开上面的 captcha.png 查看验证码。")

            captcha_code = input("请输入图片验证码：").strip()
            if not captcha_code:
                print("验证码不能为空，请重试。")
                continue

            token_response = self.session.post(
                self.base_url + SESSION_TOKEN_PATH,
                headers={"Referer": self.base_url + LOGIN_PAGE},
                timeout=self.timeout,
            )
            token_response.raise_for_status()
            encoded = encode_login_data(username, password, token_response.text.strip())

            response = self.session.post(
                self.base_url + LOGIN_PATH,
                data={
                    "userAccount": "",
                    "userPassword": "",
                    "RANDOMCODE": captcha_code,
                    "encoded": encoded,
                },
                headers={"Referer": self.base_url + LOGIN_PAGE},
                allow_redirects=True,
                timeout=self.timeout,
            )
            response.raise_for_status()

            soup = BeautifulSoup(response.text, "html.parser")
            title = clean_text(soup.title.get_text(" ", strip=True) if soup.title else "")
            message_node = soup.select_one("#showMsg")
            message = clean_text(message_node.get_text(" ", strip=True) if message_node else "")
            last_message = message or title

            still_login_page = soup.select_one("#userPassword") is not None
            if not still_login_page and "登录" not in title:
                return

            print(f"登录未成功：{message or title}")
            if "验证码" not in message:
                break

        raise RuntimeError(f"登录失败：{last_message or '未知错误'}")

    def fetch_schedule(self, term: str | None = None) -> tuple[str, BeautifulSoup]:
        """获取课表页面 HTML。term 例如 2026-2027-1。"""
        params = {"Ves632DSdyV": "NEW_XSD_PYGL"}
        if term:
            params["xnxq01id"] = term

        response = self.session.get(
            self.edu_url + SCHEDULE_PATH,
            params=params,
            headers={"Referer": self.edu_url + "/framework/xsMain.jsp"},
            timeout=self.timeout,
        )
        response.raise_for_status()
        html = response.text

        if "用户没有登录" in html or "重新登录" in html:
            raise RuntimeError("登录状态已失效，请重新运行脚本。")
        if 'id="kbtable"' not in html:
            raise RuntimeError(
                "未找到课表表格（#kbtable）。页面结构可能已变化，请使用 --debug 保存 HTML。"
            )
        return html, BeautifulSoup(html, "html.parser")


def selected_term(soup: BeautifulSoup) -> str | None:
    option = soup.select_one("#xnxq01id option[selected]")
    if option is None:
        option = soup.select_one("#xnxq01id option")
    return clean_text(option.get("value")) if option else None


def available_terms(soup: BeautifulSoup) -> list[tuple[str, str]]:
    terms: list[tuple[str, str]] = []
    for option in soup.select("#xnxq01id option"):
        value = clean_text(option.get("value"))
        label = clean_text(option.get_text(" ", strip=True)) or value
        if value:
            terms.append((value, label))
    return terms


def summarize_time(weekday: str, row_label: str, week_period: str) -> str:
    """把 1-16(周)[01-02-03节] 转成更易读的时间。"""
    parts = [weekday]

    period_match = re.search(r"\[([0-9,\-]+)节\]", week_period)
    if period_match:
        numbers = [int(item) for item in re.findall(r"\d+", period_match.group(1))]
        if numbers:
            if len(numbers) >= 2 and numbers == list(range(numbers[0], numbers[-1] + 1)):
                parts.append(f"第{numbers[0]}-{numbers[-1]}节")
            elif len(numbers) == 1:
                parts.append(f"第{numbers[0]}节")
            else:
                parts.append("第" + "、".join(str(item) for item in numbers) + "节")
    elif row_label:
        parts.append(row_label)

    week_match = re.search(
        r"(\d{1,2}(?:\s*[-~至]\s*\d{1,2})?(?:\s*[,，、]\s*\d{1,2}(?:\s*[-~至]\s*\d{1,2})?)*)\s*[（(]?\s*周",
        week_period,
    )
    if week_match:
        week_text = re.sub(r"\s+", "", week_match.group(1)).replace("~", "-").replace("至", "-")
        parts.append(f"第{week_text}周")
    elif week_period and not period_match:
        parts.append(week_period)

    return " ".join(parts)


def parse_schedule(html: str, term: str | None = None) -> tuple[str | None, list[dict[str, Any]]]:
    """解析强智教务课表网格。"""
    soup = BeautifulSoup(html, "html.parser")
    current_term = term or selected_term(soup)

    table = soup.select_one("#kbtable")
    if table is None:
        raise ValueError("页面中没有 #kbtable 课表表格")

    rows = table.find_all("tr")
    if not rows:
        raise ValueError("课表表格为空")

    header_cells = rows[0].find_all(["th", "td"], recursive=False)
    headers = [clean_text(cell.get_text(" ", strip=True)) for cell in header_cells]
    day_columns = {
        index: header
        for index, header in enumerate(headers)
        if re.fullmatch(r"星期[一二三四五六日天]", header)
    }
    if not day_columns:
        raise ValueError("没有识别到星期一至星期日的表头")

    records: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str, str, str]] = set()

    for row_index, row in enumerate(rows[1:], start=1):
        cells = row.find_all(["th", "td"], recursive=False)
        if len(cells) < 2:
            continue

        row_label = clean_text(cells[0].get_text(" ", strip=True))
        for column_index, cell in enumerate(cells[1:], start=1):
            weekday = day_columns.get(column_index)
            if weekday is None:
                continue

            # kbcontent 是完整内容，kbcontent1 是页面上显示的精简内容。
            for block in cell.select("div.kbcontent"):
                raw_text = clean_text(block.get_text(" ", strip=True))
                if not raw_text or raw_text == "\xa0":
                    continue

                strings = [clean_text(item) for item in block.stripped_strings]
                strings = [item for item in strings if item]

                meta_values: set[str] = set()
                teacher = ""
                location = ""
                week_period = ""

                for font in block.find_all("font"):
                    title = clean_text(font.get("title", ""))
                    value = clean_text(font.get_text(" ", strip=True))
                    if not value:
                        continue
                    meta_values.add(value)
                    if "老师" in title or "教师" in title:
                        teacher = value
                    elif "周次" in title:
                        week_period = value
                    elif "教室" in title or "地点" in title:
                        location = value

                course_name = next(
                    (
                        item
                        for item in strings
                        if item not in meta_values
                        and not re.fullmatch(r"[-—_=]{3,}", item)
                    ),
                    "",
                )
                course_name = re.sub(r"^[＊*]\s*", "", course_name).strip()
                if not course_name:
                    continue

                if not teacher:
                    match = re.search(r"(?:老师|教师)\s*[:：]\s*([^\s,，;；]+)", raw_text)
                    teacher = match.group(1) if match else ""
                if not location:
                    match = re.search(r"(?:教室|地点)\s*[:：]\s*([^\s,，;；]+)", raw_text)
                    location = match.group(1) if match else ""

                time_text = summarize_time(weekday, row_label, week_period)
                location = location or "未标注"
                teacher = teacher or "未标注"

                key = (course_name, weekday, week_period or row_label, location, teacher)
                if key in seen:
                    continue
                seen.add(key)

                records.append(
                    {
                        "课程名称": course_name,
                        "时间": time_text,
                        "课表显示时间": row_label,
                        "地点": location,
                        "老师": teacher,
                        "学年学期": current_term or "",
                        "原始内容": raw_text,
                        "_sort": (list(day_columns.values()).index(weekday), row_index),
                    }
                )

    records.sort(key=lambda item: item["_sort"])
    for item in records:
        item.pop("_sort", None)

    return current_term, records


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="导出重外院强智教务课表")
    parser.add_argument(
        "--term",
        help="学年学期，例如 2026-2027-1；不填则导出系统当前默认学期",
    )
    parser.add_argument(
        "--out",
        default="course_schedule.json",
        help="JSON 输出文件名，默认 course_schedule.json",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="保存 schedule_debug.html，便于页面结构变化时排查",
    )
    parser.add_argument(
        "--no-open",
        action="store_true",
        help="不自动打开 captcha.png 图片",
    )
    return parser


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:
            pass

    args = build_parser().parse_args()
    username = os.getenv("JW_USERNAME") or input("学号：").strip()
    password = os.getenv("JW_PASSWORD") or getpass.getpass("密码：")

    client = JwClient()
    try:
        print("正在登录教务系统……")
        client.login(username, password, open_captcha=not args.no_open)
        print("登录成功，正在获取课表……")

        html, soup = client.fetch_schedule(args.term)
        terms = available_terms(soup)
        if terms:
            print("可查询学期：" + "、".join(value for value, _ in terms))

        term, records = parse_schedule(html, args.term)
        output_path = Path(args.out).resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)

        result = {
            "来源": client.edu_url + SCHEDULE_PATH,
            "学年学期": term or "",
            "导出时间": datetime.now().astimezone().isoformat(timespec="seconds"),
            "课程数量": len(records),
            "课程": records,
        }
        output_path.write_text(
            json.dumps(result, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        if args.debug:
            debug_path = output_path.with_name("schedule_debug.html")
            debug_path.write_text(html, encoding="utf-8")
            print(f"调试页面：{debug_path}")

        print(f"已导出 {len(records)} 条课程记录：{output_path}")
        for item in records:
            print(f"  {item['时间']} | {item['课程名称']} | {item['地点']} | {item['老师']}")
        return 0
    except Exception as exc:
        print(f"失败：{exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

