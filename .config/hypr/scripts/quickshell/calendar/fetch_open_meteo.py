#!/usr/bin/env python3
import sys
import json
import urllib.request
from datetime import datetime

def get_location():
    # Attempt automatic IP geolocation
    try:
        req = urllib.request.Request("http://ip-api.com/json", headers={"User-Agent": "WeatherFetch/1.0"})
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            data = json.loads(resp.read().decode())
            if data.get("status") == "success":
                return float(data.get("lat", -17.8216)), float(data.get("lon", 31.0492)), data.get("city", "Harare")
    except Exception:
        pass
    # Fallback default location (Harare, Zimbabwe)
    return -17.8216, 31.0492, "Harare"

def get_icon_and_meta(code, is_day=True):
    # Map WMO weather code to icon, description, and Catppuccin mocha hex
    if code == 0:
        return ("" if is_day else "", "Clear" if not is_day else "Sunny", "#f9e2af" if is_day else "#cba6f7")
    elif code == 1:
        return ("" if is_day else "", "Mainly Clear", "#f9e2af" if is_day else "#cba6f7")
    elif code in (2, 3):
        return ("", "Partly Cloudy" if code == 2 else "Overcast", "#bac2de")
    elif code in (45, 48):
        return ("󰖑", "Fog", "#84afdb")
    elif code in (51, 53, 55, 56, 57):
        return ("󰖗", "Drizzle", "#74c7ec")
    elif code in (61, 63, 65, 66, 67, 80, 81, 82):
        return ("󰖗", "Rainy", "#74c7ec")
    elif code in (71, 73, 75, 77, 85, 86):
        return ("", "Snow", "#cdd6f4")
    elif code in (95, 96, 99):
        return ("", "Storm", "#f9e2af")
    return ("", "Cloudy", "#cdd6f4")

def fetch_weather(target_file=None, unit="metric"):
    lat, lon, city = get_location()
    
    temp_unit_param = ""
    wind_unit_param = ""
    if unit == "imperial":
        temp_unit_param = "&temperature_unit=fahrenheit"
        wind_unit_param = "&wind_speed_unit=mph"
        
    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        f"&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day"
        f"&hourly=temperature_2m,weather_code"
        f"&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,wind_speed_10m_max"
        f"&timezone=auto{temp_unit_param}{wind_unit_param}"
    )
    
    req = urllib.request.Request(url, headers={"User-Agent": "WeatherApp/1.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode())
        
    curr = data.get("current", {})
    c_temp = "{:.1f}".format(curr.get("temperature_2m", 0.0))
    c_code = curr.get("weather_code", 0)
    is_day = bool(curr.get("is_day", 1))
    c_icon, c_desc, c_hex = get_icon_and_meta(c_code, is_day)
    
    daily = data.get("daily", {})
    hourly = data.get("hourly", {})
    forecast = []
    
    num_days = min(5, len(daily.get("time", [])))
    for i in range(num_days):
        d_str = daily["time"][i]
        dt = datetime.strptime(d_str, "%Y-%m-%d")
        code = daily["weather_code"][i]
        icon, desc, hex_col = get_icon_and_meta(code, True)
        
        day_hourly = []
        for h_idx, h_time_str in enumerate(hourly.get("time", [])):
            if h_time_str.startswith(d_str):
                h_time = h_time_str.split("T")[1]
                h_temp = "{:.1f}".format(hourly["temperature_2m"][h_idx])
                h_code = hourly["weather_code"][h_idx]
                h_hour = int(h_time.split(":")[0])
                h_is_day = 6 <= h_hour <= 18
                h_icon, _, h_hex = get_icon_and_meta(h_code, h_is_day)
                day_hourly.append({
                    "time": h_time,
                    "temp": h_temp,
                    "icon": h_icon,
                    "hex": h_hex
                })
                
        forecast.append({
            "id": str(i),
            "day": dt.strftime("%a"),
            "day_full": dt.strftime("%A"),
            "date": dt.strftime("%d %b"),
            "max": "{:.1f}".format(daily["temperature_2m_max"][i]),
            "min": "{:.1f}".format(daily["temperature_2m_min"][i]),
            "feels_like": "{:.1f}".format(daily["apparent_temperature_max"][i]),
            "wind": str(round(daily["wind_speed_10m_max"][i])),
            "humidity": str(round(curr.get("relative_humidity_2m", 50))),
            "pop": str(daily["precipitation_probability_max"][i]),
            "icon": icon,
            "hex": hex_col,
            "desc": desc,
            "hourly": day_hourly
        })
        
    result = {
        "current_temp": c_temp,
        "current_icon": c_icon,
        "current_hex": c_hex,
        "forecast": forecast
    }
    
    json_str = json.dumps(result)
    if target_file:
        with open(target_file, "w") as f:
            f.write(json_str)
    return json_str

if __name__ == "__main__":
    out_file = sys.argv[1] if len(sys.argv) > 1 else None
    unit_mode = sys.argv[2] if len(sys.argv) > 2 else "metric"
    try:
        print(fetch_weather(out_file, unit_mode))
    except Exception as e:
        sys.stderr.write(f"Failed to fetch weather: {e}\n")
        sys.exit(1)
