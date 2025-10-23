import os
import json
import uuid
import time
import shlex
import signal
import subprocess
from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory, abort

APP_DIR = Path(__file__).resolve().parent
HOME = Path(os.path.expanduser("~")).resolve()
JOBS_DIR = APP_DIR / "jobs_tmp"
STATIC_DIR = APP_DIR / "static"
JOBS_DIR.mkdir(parents=True, exist_ok=True)

app = Flask(__name__, static_folder=str(STATIC_DIR), static_url_path='')

def safe_join(base: Path, rel: str) -> Path:
    target = (base / rel.lstrip("/")).resolve()
    if not str(target).startswith(str(HOME)):
        raise ValueError("Ruta fuera de HOME no permitida")
    return target

def job_paths(job_id: str):
    base = JOBS_DIR / job_id
    return {
        "log": base.with_suffix(".log"),
        "pid": base.with_suffix(".pid"),
        "meta": base.with_suffix(".json"),
    }

def proc_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False

@app.get("/api/health")
def health():
    return jsonify(status="ok", time=int(time.time()))

@app.get("/api/fs/list")
def fs_list():
    path = request.args.get("path", str(HOME))
    try:
        p = safe_join(HOME, path)
        if not p.exists():
            return jsonify(error="No existe"), 404
        entries = []
        for child in sorted(p.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
            try:
                stat = child.stat()
                entries.append({
                    "name": child.name,
                    "path": str(child),
                    "is_dir": child.is_dir(),
                    "size": stat.st_size,
                    "mtime": int(stat.st_mtime),
                })
            except Exception:
                continue
        return jsonify(path=str(p), entries=entries)
    except Exception as e:
        return jsonify(error=str(e)), 400

@app.post("/api/fs/mkdir")
def fs_mkdir():
    data = request.get_json(silent=True) or {}
    path = data.get("path")
    if not path:
        return jsonify(error="Falta 'path'"), 400
    try:
        p = safe_join(HOME, path)
        p.mkdir(parents=True, exist_ok=True)
        return jsonify(ok=True, path=str(p))
    except Exception as e:
        return jsonify(error=str(e)), 400

@app.post("/api/fs/create")
def fs_create():
    data = request.get_json(silent=True) or {}
    path = data.get("path")
    content = data.get("content", "")
    if not path:
        return jsonify(error="Falta 'path'"), 400
    try:
        p = safe_join(HOME, path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        return jsonify(ok=True, path=str(p), size=len(content.encode("utf-8")))
    except Exception as e:
        return jsonify(error=str(e)), 400

@app.post("/api/fs/move")
def fs_move():
    data = request.get_json(silent=True) or {}
    src = data.get("src")
    dst = data.get("dst")
    if not src or not dst:
        return jsonify(error="Faltan 'src' y/o 'dst'"), 400
    try:
        s = safe_join(HOME, src)
        d = safe_join(HOME, dst)
        d.parent.mkdir(parents=True, exist_ok=True)
        os.rename(s, d)
        return jsonify(ok=True, src=str(s), dst=str(d))
    except Exception as e:
        return jsonify(error=str(e)), 400

@app.post("/api/fs/delete")
def fs_delete():
    data = request.get_json(silent=True) or {}
    path = data.get("path")
    recursive = bool(data.get("recursive", False))
    if not path:
        return jsonify(error="Falta 'path'"), 400
    try:
        p = safe_join(HOME, path)
        if p.is_dir():
            if recursive:
                import shutil
                shutil.rmtree(p)
            else:
                p.rmdir()
        else:
            p.unlink()
        return jsonify(ok=True, path=str(p))
    except Exception as e:
        return jsonify(error=str(e)), 400

@app.post("/api/jobs/start")
def jobs_start():
    data = request.get_json(silent=True) or {}
    cmd = data.get("cmd")
    if not cmd:
        cmd = "sh -lc 'echo Iniciando trabajo; date; sleep 5; echo Trabajo listo; date'"
    if isinstance(cmd, list):
        shell = False
        popen_cmd = cmd
        cmd_str = " ".join(shlex.quote(c) for c in cmd)
    else:
        shell = True
        popen_cmd = cmd
        cmd_str = cmd

    job_id = uuid.uuid4().hex[:12]
    paths = job_paths(job_id)
    meta = {
        "id": job_id,
        "cmd": cmd_str,
        "status": "running",
        "start": int(time.time()),
        "end": None,
        "log": str(paths["log"]),
        "pid": None,
    }
    with open(paths["log"], "w", encoding="utf-8") as logf:
        logf.write(f"== Job {job_id} ==\nCMD: {cmd_str}\nSTART: {time.ctime()}\n\n")
    with open(paths["meta"], "w", encoding="utf-8") as mf:
        json.dump(meta, mf)

    with open(paths["log"], "a", encoding="utf-8") as logf:
        proc = subprocess.Popen(
            popen_cmd,
            shell=shell,
            stdout=logf,
            stderr=logf,
            cwd=str(HOME),
            preexec_fn=os.setsid
        )
    with open(paths["pid"], "w", encoding="utf-8") as pf:
        pf.write(str(proc.pid))
    meta["pid"] = proc.pid
    with open(paths["meta"], "w", encoding="utf-8") as mf:
        json.dump(meta, mf)
    return jsonify(ok=True, id=job_id, pid=proc.pid, log=Path(paths["log"]).name)

@app.get("/api/jobs/status/<job_id>")
def jobs_status(job_id):
    paths = job_paths(job_id)
    if not Path(paths["meta"]).exists():
        return jsonify(error="Job no encontrado"), 404
    with open(paths["meta"], "r", encoding="utf-8") as mf:
        meta = json.load(mf)
    pid = meta.get("pid")
    running = False
    if pid:
        running = proc_running(pid)
    if running:
        meta["status"] = "running"
    else:
        meta["status"] = "done"
        if meta.get("end") is None:
            meta["end"] = int(time.time())
            with open(paths["meta"], "w", encoding="utf-8") as mf:
                json.dump(meta, mf)
    return jsonify(meta)

@app.post("/api/jobs/stop/<job_id>")
def jobs_stop(job_id):
    paths = job_paths(job_id)
    if not Path(paths["pid"]).exists():
        return jsonify(error="PID no encontrado"), 404
    pid = int(Path(paths["pid"]).read_text().strip())
    try:
        os.killpg(os.getpgid(pid), signal.SIGTERM)
        time.sleep(0.5)
    except Exception as e:
        return jsonify(error=str(e)), 400
    return jsonify(ok=True, stopped=pid)

@app.get("/api/jobs/log/<job_id>")
def jobs_log(job_id):
    paths = job_paths(job_id)
    logp = Path(paths["log"])
    if not logp.exists():
        return jsonify(error="Log no encontrado"), 404
    tail = int(request.args.get("tail", "500"))
    try:
        with open(logp, "r", encoding="utf-8") as f:
            lines = f.readlines()[-tail:]
        return jsonify(log="".join(lines))
    except Exception as e:
        return jsonify(error=str(e)), 400

@app.get("/")
def index():
    return send_from_directory(str(STATIC_DIR), "index.html")

if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "5000"))
    debug = os.environ.get("FLASK_ENV", "") == "development"
    app.run(host=host, port=port, debug=debug)