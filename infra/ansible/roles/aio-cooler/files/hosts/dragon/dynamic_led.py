import json
import subprocess
import time
import sys

DEVICE_MATCH = 'h100i'
REFRESH_INTERVAL = 60
TEMP_THRESHOLD = 40
COLOR_COOL = '0080ff'
COLOR_HOT = 'ff0000'


def set_led_color(color: str) -> None:
    subprocess.run(
        ['liquidctl', '--match', DEVICE_MATCH, 'set', 'led', 'color', 'fixed', color],
        check=False,
    )


def main() -> int:
    while True:
        try:
            status = json.loads(
                subprocess.check_output(
                    ['liquidctl', '--match', DEVICE_MATCH, 'status', '--json']
                )
            )
            liquid_temp = status[0]['status'][0]['value']
            color = COLOR_COOL if liquid_temp < TEMP_THRESHOLD else COLOR_HOT
            set_led_color(color)
        except subprocess.CalledProcessError as exc:
            print(f"liquidctl failed: {exc}", file=sys.stderr)
        except (KeyError, IndexError, json.JSONDecodeError) as exc:
            print(f"Failed to parse liquidctl output: {exc}", file=sys.stderr)
        except Exception as exc:
            print(f"Unexpected error: {exc}", file=sys.stderr)

        time.sleep(REFRESH_INTERVAL)


if __name__ == '__main__':
    sys.exit(main())
