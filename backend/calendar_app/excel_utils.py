import io
import re
import zipfile
import xml.etree.ElementTree as ET
import nepali_datetime
from calendar_app.utilities import total_days_in_month

EXCEL_HEADERS = [
    "Title",
    "Category",
    "Start Date (BS)",
    "End Date (BS)",
    "Location",
    "Is Holiday (Yes/No)",
    "Is Important (Yes/No)",
    "Description",
]

INSTRUCTION_ROWS = [
    ["Column", "Required?", "Format / Allowed Values", "Notes"],
    ["Title", "Yes", "Text (e.g. Dashain Holiday)", "Event or holiday title."],
    ["Category", "No", "Text (e.g. Festival, Meeting)", "Auto-matches or creates a category in your organization."],
    ["Start Date (BS)", "Yes", "YYYY-MM-DD (e.g. 2083-08-15)", "Must be a valid Nepali Bikram Sambat (B.S.) date."],
    ["End Date (BS)", "No", "YYYY-MM-DD (e.g. 2083-08-18)", "Defaults to Start Date (BS) if left blank. Must be >= Start Date."],
    ["Location", "No", "Text (e.g. Head Office)", "Optional event venue or location."],
    ["Is Holiday (Yes/No)", "No", "Yes / No (or True / False, 1 / 0)", "Set Yes for official public/company holidays."],
    ["Is Important (Yes/No)", "No", "Yes / No (or True / False, 1 / 0)", "Set Yes to highlight as an important event."],
    ["Description", "No", "Text", "Additional details or agenda notes."],
]


def _col_index_to_letter(idx: int) -> str:
    """Convert 0-based column index to Excel column letters (0 -> A, 25 -> Z, 26 -> AA)."""
    result = ""
    n = idx + 1
    while n > 0:
        n, rem = divmod(n - 1, 26)
        result = chr(65 + rem) + result
    return result


def _col_letter_to_index(cell_ref: str) -> int:
    """Extract column letters from cell ref like 'C12' and convert to 0-based index."""
    match = re.match(r"^([A-Za-z]+)", cell_ref or "")
    if not match:
        return -1
    letters = match.group(1).upper()
    idx = 0
    for ch in letters:
        idx = idx * 26 + (ord(ch) - 64)
    return idx - 1


def _xml_escape(val: str) -> str:
    return (
        val.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
    )


def _build_worksheet_xml(all_rows: list[list[str]]) -> str:
    lines = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
        "  <sheetData>",
    ]
    for r_idx, row in enumerate(all_rows, start=1):
        lines.append(f'    <row r="{r_idx}">')
        for c_idx, cell_val in enumerate(row):
            col_letter = _col_index_to_letter(c_idx)
            text = "" if cell_val is None else str(cell_val)
            escaped = _xml_escape(text)
            lines.append(
                f'      <c r="{col_letter}{r_idx}" t="inlineStr"><is><t xml:space="preserve">{escaped}</t></is></c>'
            )
        lines.append("    </row>")
    lines.append("  </sheetData>")
    lines.append("</worksheet>")
    return "\n".join(lines)


def _build_xlsx_stdlib(
    rows: list[list[str]],
    sheet_title: str = "Calendar Events",
    include_instructions: bool = False,
) -> bytes:
    """Pure-Python OpenXML (.xlsx) builder requiring zero third-party packages."""
    buf = io.BytesIO()
    sheet1_rows = [EXCEL_HEADERS] + rows
    sheet1_xml = _build_worksheet_xml(sheet1_rows)

    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        content_types = [
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
            '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
            '  <Default Extension="xml" ContentType="application/xml"/>',
            '  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
            '  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
        ]
        if include_instructions:
            content_types.append(
                '  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            )
        content_types.append("</Types>")
        zf.writestr("[Content_Types].xml", "\n".join(content_types))

        rels = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
            '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\n'
            "</Relationships>"
        )
        zf.writestr("_rels/.rels", rels)

        safe_title = _xml_escape(sheet_title[:31] or "Calendar Events")
        wb_lines = [
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
            "  <sheets>",
            f'    <sheet name="{safe_title}" sheetId="1" r:id="rId1"/>',
        ]
        if include_instructions:
            wb_lines.append('    <sheet name="Instructions" sheetId="2" r:id="rId2"/>')
        wb_lines.extend(["  </sheets>", "</workbook>"])
        zf.writestr("xl/workbook.xml", "\n".join(wb_lines))

        wb_rels = [
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
            '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>',
        ]
        if include_instructions:
            wb_rels.append(
                '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'
            )
        wb_rels.append("</Relationships>")
        zf.writestr("xl/_rels/workbook.xml.rels", "\n".join(wb_rels))

        zf.writestr("xl/worksheets/sheet1.xml", sheet1_xml)
        if include_instructions:
            sheet2_xml = _build_worksheet_xml(INSTRUCTION_ROWS)
            zf.writestr("xl/worksheets/sheet2.xml", sheet2_xml)

    return buf.getvalue()


def build_events_xlsx(
    rows: list[list[str]],
    sheet_title: str = "Calendar Events",
    include_instructions: bool = False,
) -> bytes:
    """Build an .xlsx file using openpyxl if installed, or pure-Python OpenXML fallback."""
    try:
        import openpyxl
        from openpyxl.styles import Alignment, Font, PatternFill
        from openpyxl.utils import get_column_letter

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = (sheet_title or "Calendar Events")[:31]

        header_fill = PatternFill(start_color="4F46E5", end_color="4F46E5", fill_type="solid")
        header_font = Font(bold=True, color="FFFFFF")

        ws.append(EXCEL_HEADERS)
        for col_idx in range(1, len(EXCEL_HEADERS) + 1):
            cell = ws.cell(row=1, column=col_idx)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")

        for row in rows:
            ws.append(["" if v is None else str(v) for v in row])

        for col_idx in range(1, len(EXCEL_HEADERS) + 1):
            col_letter = get_column_letter(col_idx)
            max_len = max(
                len(str(ws.cell(row=r, column=col_idx).value or ""))
                for r in range(1, ws.max_row + 1)
            )
            ws.column_dimensions[col_letter].width = max(max_len + 4, 16)

        if include_instructions:
            ws_inst = wb.create_sheet(title="Instructions")
            for r_i, inst_row in enumerate(INSTRUCTION_ROWS, start=1):
                ws_inst.append(inst_row)
                if r_i == 1:
                    for c_i in range(1, len(inst_row) + 1):
                        c = ws_inst.cell(row=1, column=c_i)
                        c.fill = header_fill
                        c.font = header_font
            for col_idx in range(1, 5):
                col_letter = get_column_letter(col_idx)
                ws_inst.column_dimensions[col_letter].width = 34

        buf = io.BytesIO()
        wb.save(buf)
        return buf.getvalue()
    except ImportError:
        return _build_xlsx_stdlib(
            rows=rows,
            sheet_title=sheet_title,
            include_instructions=include_instructions,
        )


def _parse_xlsx_stdlib(file_bytes: bytes) -> list[list[str]]:
    """Pure-Python OpenXML (.xlsx) reader supporting sharedStrings and inlineStr."""
    ns = {"main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(io.BytesIO(file_bytes), "r") as zf:
        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in zf.namelist():
            ss_root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
            for si in ss_root.findall("main:si", ns):
                texts = [t.text or "" for t in si.findall(".//main:t", ns)]
                shared_strings.append("".join(texts))

        sheet_path = "xl/worksheets/sheet1.xml"
        if sheet_path not in zf.namelist():
            worksheet_files = sorted(
                n for n in zf.namelist() if n.startswith("xl/worksheets/sheet") and n.endswith(".xml")
            )
            if not worksheet_files:
                raise ValueError("No worksheet found in uploaded Excel file.")
            sheet_path = worksheet_files[0]

        sheet_root = ET.fromstring(zf.read(sheet_path))
        parsed_rows: list[list[str]] = []

        for row_el in sheet_root.findall(".//main:sheetData/main:row", ns):
            cells_by_col: dict[int, str] = {}
            max_col = -1
            for seq_idx, c_el in enumerate(row_el.findall("main:c", ns)):
                cell_ref = c_el.attrib.get("r", "")
                col_idx = _col_letter_to_index(cell_ref)
                if col_idx < 0:
                    col_idx = seq_idx
                max_col = max(max_col, col_idx)

                cell_type = c_el.attrib.get("t", "")
                val = ""
                if cell_type == "s":
                    v_el = c_el.find("main:v", ns)
                    if v_el is not None and v_el.text is not None:
                        s_idx = int(v_el.text)
                        if 0 <= s_idx < len(shared_strings):
                            val = shared_strings[s_idx]
                elif cell_type == "inlineStr":
                    texts = [t.text or "" for t in c_el.findall(".//main:is//main:t", ns)]
                    val = "".join(texts)
                elif cell_type == "b":
                    v_el = c_el.find("main:v", ns)
                    val = "Yes" if (v_el is not None and v_el.text == "1") else "No"
                else:
                    v_el = c_el.find("main:v", ns)
                    if v_el is not None and v_el.text is not None:
                        val = v_el.text
                cells_by_col[col_idx] = val.strip()

            if max_col >= 0:
                row_vals = [cells_by_col.get(i, "") for i in range(max_col + 1)]
                parsed_rows.append(row_vals)
            else:
                parsed_rows.append([])

        return parsed_rows


def parse_events_xlsx(file_bytes: bytes) -> list[list[str]]:
    """Return all rows from the first worksheet as a list of string lists."""
    try:
        import openpyxl

        wb = openpyxl.load_workbook(io.BytesIO(file_bytes), data_only=True)
        ws = wb.worksheets[0]
        rows: list[list[str]] = []
        for row in ws.iter_rows(values_only=True):
            rows.append(["" if v is None else str(v).strip() for v in row])
        return rows
    except ImportError:
        return _parse_xlsx_stdlib(file_bytes)


def parse_nepali_date_cell(raw_value: str, field_label: str) -> nepali_datetime.date:
    """Validate and parse a B.S. YYYY-MM-DD date string from an Excel cell."""
    cleaned = (raw_value or "").strip().split(" ")[0].replace("/", "-")
    if not cleaned:
        raise ValueError(f"{field_label} is required (expected YYYY-MM-DD B.S.).")
    parts = cleaned.split("-")
    if len(parts) != 3:
        raise ValueError(f"Invalid {field_label} '{raw_value}': expected YYYY-MM-DD B.S. format.")
    try:
        y, m, d = int(parts[0]), int(parts[1]), int(parts[2])
    except ValueError:
        raise ValueError(f"Invalid {field_label} '{raw_value}': year, month, and day must be numbers.")

    if not (1975 <= y <= 2100):
        raise ValueError(f"Invalid {field_label} '{raw_value}': B.S. year must be between 1975 and 2100.")
    if not (1 <= m <= 12):
        raise ValueError(f"Invalid {field_label} '{raw_value}': month must be between 1 and 12.")

    max_days = total_days_in_month(y, m)
    if not (1 <= d <= max_days):
        raise ValueError(
            f"Invalid {field_label} '{raw_value}': day {d} is out of range for B.S. {y}-{m:02d} (max {max_days} days)."
        )
    return nepali_datetime.date(y, m, d)


def parse_bool_cell(raw_value: str) -> bool:
    cleaned = (raw_value or "").strip().lower()
    return cleaned in {"yes", "y", "true", "1", "holiday", "important"}
