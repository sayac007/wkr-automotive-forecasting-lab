import numpy as np

from wkr_pipeline import sales_forecast_pipeline as forecast


def test_metrics_perfect_prediction():
    result = forecast.metrics(np.array([100.0, 200.0]), np.array([100.0, 200.0]))
    assert result["mae_eur"] == 0.0
    assert result["rmse_eur"] == 0.0
    assert result["mape_pct"] == 0.0


def test_forecast_horizon_is_sep_dec_2026():
    assert forecast.FORECAST_START.isoformat() == "2026-09-01T00:00:00"
    assert forecast.FORECAST_END.isoformat() == "2026-12-31T00:00:00"


def test_expected_segments_are_fixed():
    assert len(forecast.SEGMENTS) == 6
    assert "Powertrain Mounts" in forecast.SEGMENTS
