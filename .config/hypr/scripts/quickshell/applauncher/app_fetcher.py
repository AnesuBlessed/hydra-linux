#!/usr/bin/env python3
import os
import glob
import json
import re

# Pre-index Papirus and pixmaps icon paths for instant O(1) resolution
ICON_MAP = {}
home = os.path.expanduser('~')
icon_search_dirs = [
    f'{home}/.local/share/icons',
    '/usr/share/icons/Papirus/48x48/apps',
    '/usr/share/icons/Papirus/64x64/apps',
    '/usr/share/icons/Papirus/32x32/apps',
    '/usr/share/icons/Papirus/scalable/apps',
    '/usr/share/icons/hicolor/48x48/apps',
    '/usr/share/icons/hicolor/scalable/apps',
    '/usr/share/pixmaps',
]

def build_icon_map():
    for idir in icon_search_dirs:
        if not os.path.exists(idir):
            continue
        for root, _, files in os.walk(idir):
            for file in files:
                if file.endswith(('.svg', '.png', '.xpm')):
                    base_name = os.path.splitext(file)[0]
                    if base_name not in ICON_MAP:
                        ICON_MAP[base_name] = os.path.join(root, file)

build_icon_map()

def resolve_icon(icon_name):
    if not icon_name:
        return "application-x-executable"
    if icon_name.startswith("/"):
        if os.path.exists(icon_name):
            return icon_name
        base = os.path.splitext(os.path.basename(icon_name))[0]
        return ICON_MAP.get(base, icon_name)
    base = os.path.splitext(icon_name)[0]
    return ICON_MAP.get(base, icon_name)

def fetch_apps():
    apps = {}
    dirs = [
        f'{home}/.local/share/applications',
        '/usr/local/share/applications',
        '/usr/share/applications',
        '/var/lib/flatpak/exports/share/applications',
        f'{home}/.local/share/flatpak/exports/share/applications',
        f'{home}/.nix-profile/share/applications',
        '/run/current-system/sw/share/applications'
    ]
    
    for d in dirs:
        if not os.path.exists(d):
            continue
            
        for f in glob.glob(os.path.join(d, '**/*.desktop'), recursive=True):
            try:
                with open(f, 'r', encoding='utf-8', errors='ignore') as file:
                    app = {'name': '', 'exec': '', 'icon': ''}
                    is_desktop = False
                    no_display = False
                    terminal = False
                    app_type = "Application"
                    
                    for line in file:
                        line = line.strip()
                        if line == '[Desktop Entry]':
                            is_desktop = True
                            continue
                        elif line.startswith('[') and line.endswith(']'):
                            is_desktop = False
                            continue
                            
                        if is_desktop and '=' in line:
                            key, val = line.split('=', 1)
                            key = key.strip()
                            val = val.strip()
                            
                            if key == 'Type':
                                app_type = val
                            elif key == 'Name' and not app['name']:
                                app['name'] = val
                            elif key == 'Exec' and not app['exec']:
                                app['exec'] = val
                            elif key == 'Icon' and not app['icon']:
                                app['icon'] = val
                            elif key == 'NoDisplay' and val.lower() in ('true', '1'):
                                no_display = True
                            elif key == 'Hidden' and val.lower() in ('true', '1'):
                                no_display = True
                            elif key == 'Terminal' and val.lower() in ('true', '1'):
                                terminal = True
                                
                    if app_type != 'Application':
                        continue

                    if app['name'] and app['exec'] and not no_display:
                        clean_exec = re.sub(r'%[a-zA-Z]', '', app['exec']).strip()
                        clean_exec = re.sub(r'@@[a-zA-Z]?\s*', '', clean_exec).strip()
                        clean_exec = re.sub(r'\s+--$', '', clean_exec).strip()
                        
                        if terminal:
                            clean_exec = f"kitty -e {clean_exec}"
                            
                        app['exec'] = clean_exec
                        app['icon'] = resolve_icon(app['icon'])
                        
                        if app['name'] not in apps:
                            apps[app['name']] = app
            except Exception:
                pass
                
    res = list(apps.values())
    res.sort(key=lambda x: x['name'].lower())
    print(json.dumps(res))

if __name__ == "__main__":
    fetch_apps()
