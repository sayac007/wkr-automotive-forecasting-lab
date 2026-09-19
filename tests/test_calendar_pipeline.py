from datetime import date
from src.wkr_pipeline.calendar_pipeline import easter_sunday, demand_feature_dates

def test_easter_2026():
    assert easter_sunday(2026) == date(2026, 4, 5)

def test_research_features_2026():
    f = demand_feature_dates(2026)
    assert f["Karfreitag"] == {date(2026, 4, 2), date(2026, 4, 4)}
    assert f["ErsterMai"] == {date(2026, 4, 30)}
    assert f["Pfingsten"] == {date(2026, 5, 23)}
    assert f["Himmelfahrt"] == {date(2026, 5, 13)}
    assert f["Silvester"] == {date(2026, 12, 31)}
