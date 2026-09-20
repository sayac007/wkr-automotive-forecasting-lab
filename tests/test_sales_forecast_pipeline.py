import importlib.util
from pathlib import Path

import numpy as np

MODULE = Path(__file__).parents[1] / "src" / "wkr_pipeline" / "sales_forecast_pipeline.py"
spec = importlib.util.spec_from_file_location("sales_forecast_pipeline", MODULE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def test_metrics_perfect_prediction():
    result = m.metrics(np.array([100.0, 200.0]), np.array([100.0, 200.0]))
    assert result["mae_eur"] == 0.0
    assert result["rmse_eur"] == 0.0
    assert result["mape_pct"] == 0.0


def test_forecast_horizon_is_sep_dec_2026():
    assert m.FORECAST_START.isoformat() == "2026-09-01T00:00:00"
    assert m.FORECAST_END.isoformat() == "2026-12-31T00:00:00"


def test_expected_segments_are_fixed():
    assert len(m.SEGMENTS) == 6
    assert "Powertrain Mounts" in m.SEGMENTS
