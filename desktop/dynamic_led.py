import json
import subprocess
import time

while True:
    status = json.loads(subprocess.check_output(['liquidctl', '--match', 'h100i', 'status', '--json']))
    liquid_temp = status[0]['status'][0]['value']  # Liquid temperature
    color = '0080ff' if liquid_temp < 40 else 'ff0000'  # Blue if <40°C, red if ≥40°C
    subprocess.run(['liquidctl', '--match', 'h100i', 'set', 'led', 'color', 'fixed', color])
    time.sleep(60)
