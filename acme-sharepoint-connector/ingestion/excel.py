import io

import pandas as pd


def read_excel(file: io.BytesIO, sheet: str | None, header: int = 0) -> pd.DataFrame:
    return pd.read_excel(file, sheet_name=sheet if sheet else 0, header=header)


def infer_sqlserver_type(series: pd.Series) -> str:
    if series.dropna().empty:
        return "NVARCHAR(50)"
    if pd.api.types.is_bool_dtype(series):
        return "BIT"
    if pd.api.types.is_integer_dtype(series):
        return "BIGINT"
    if pd.api.types.is_float_dtype(series):
        return "FLOAT"
    if pd.api.types.is_datetime64_any_dtype(series):
        return "DATETIME2"

    max_len = series.dropna().astype(str).str.len().max()
    if max_len <= 4000:
        return "NVARCHAR(4000)"
    return "NVARCHAR(MAX)"


def build_metadata(df: pd.DataFrame) -> list[dict]:
    return [
        {"name": col, "sql_type": infer_sqlserver_type(df[col])}
        for col in df.columns
    ]


def rows_to_insert(df: pd.DataFrame) -> list[tuple]:
    return [
        tuple(None if pd.isna(v) else v for v in row)
        for row in df.itertuples(index=False, name=None)
    ]
