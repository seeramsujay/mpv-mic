import os
import subprocess
import pytest

SCRIPT_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "mpv-mic.sh"))

def run_bash_func(cmd: str) -> str:
    full_cmd = f'source "{SCRIPT_PATH}"\n{cmd}'
    res = subprocess.run(["bash", "-c", full_cmd], capture_output=True, text=True)
    assert res.returncode == 0, f"Error running bash: {res.stderr}"
    return res.stdout.strip()

def test_truncate_string_short():
    out = run_bash_func('truncate_string "short" 10')
    assert out == "short"

def test_truncate_string_long():
    out = run_bash_func('truncate_string "this_is_a_very_long_string" 12')
    assert out == "this_is_a..."
    assert len(out) == 12

def test_format_size():
    assert run_bash_func('format_size 500') == "500 B"
    assert run_bash_func('format_size 2048') == "2 KB"
    assert run_bash_func('format_size 5242880') == "5 MB"

def test_syntax():
    res = subprocess.run(["bash", "-n", SCRIPT_PATH], capture_output=True, text=True)
    assert res.returncode == 0
