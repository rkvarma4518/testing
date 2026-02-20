from flask import Flask, jsonify
import csv
import os
import psutil

app = Flask(__name__)

CSV_PATH = "/mnt/files/data.csv"  # mounted file share path

@app.route("/read-csv")
def read_csv():
    if not os.path.exists(CSV_PATH):
        return {"error": "CSV file not found"}, 404

    rows = []
    with open(CSV_PATH, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        rows = list(reader)
        # for row in reader:
        #     rows.append(row)
            # break

    return jsonify({'row count':len(rows)})


@app.route("/metrics")
def metrics():
    memory = psutil.virtual_memory()
    cpu = psutil.cpu_percent(interval=1)

    return jsonify({
        "cpu_percent": cpu,
        "total_memory_mb": round(memory.total / (1024 * 1024), 2),
        "used_memory_mb": round(memory.used / (1024 * 1024), 2),
        "free_memory_mb": round(memory.available / (1024 * 1024), 2)
    })


@app.route("/")
def home():
    return "Flask App running with Azure File Share 🚀"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)





