#!/usr/bin/env python3
"""Sonos playlist manager — list / save / play"""
import sys
import soco

DEFAULT_ROOM = "書房"

def get_speaker(name: str):
    speakers = list(soco.discover() or [])
    if not speakers:
        print("ERROR: 找不到 Sonos 音響，請確認 Local Network 權限已開啟")
        sys.exit(1)
    for s in speakers:
        if s.player_name == name:
            return s
    print(f"ERROR: 找不到房間「{name}」，可用房間：{[s.player_name for s in speakers]}")
    sys.exit(1)

def cmd_list(room: str):
    s = get_speaker(room)
    playlists = s.get_sonos_playlists()
    if not playlists:
        print("目前沒有播放清單")
        return
    for i, pl in enumerate(playlists, 1):
        print(f"{i}. {pl.title}")

def cmd_save(name: str, room: str):
    s = get_speaker(room)
    if s.queue_size == 0:
        print("ERROR: 目前 queue 是空的，無法儲存")
        sys.exit(1)
    existing = [pl for pl in s.get_sonos_playlists() if pl.title == name]
    if existing:
        s.remove_sonos_playlist(existing[0])
    pl = s.create_sonos_playlist_from_queue(title=name)
    count = s.queue_size
    print(f"OK: 已儲存為「{name}」（共 {count} 首）")

def cmd_play(name: str, room: str):
    s = get_speaker(room)
    playlists = s.get_sonos_playlists()
    match = [pl for pl in playlists if pl.title == name]
    if not match:
        print(f"ERROR: 找不到清單「{name}」")
        print("可用清單：")
        for i, pl in enumerate(playlists, 1):
            print(f"{i}. {pl.title}")
        sys.exit(1)
    s.clear_queue()
    container = s.music_library.browse(ml_item=match[0])
    tracks = list(container) if container else []
    if not tracks:
        print(f"ERROR: 清單「{name}」沒有歌曲")
        sys.exit(1)
    s.add_multiple_to_queue(tracks)
    s.play_from_queue(0)
    print(f"OK: 正在播放「{name}」")

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Sonos playlist manager")
    parser.add_argument("command", choices=["list", "save", "play"])
    parser.add_argument("playlist_name", nargs="?", default=None)
    parser.add_argument("--name", default=DEFAULT_ROOM, help="房間名稱")
    args = parser.parse_args()

    if args.command == "list":
        cmd_list(args.name)
    elif args.command == "save":
        if not args.playlist_name:
            print("ERROR: 請提供清單名稱，例如: save \"爵士夜\"")
            sys.exit(1)
        cmd_save(args.playlist_name, args.name)
    elif args.command == "play":
        if not args.playlist_name:
            print("ERROR: 請提供清單名稱，例如: play \"爵士夜\"")
            sys.exit(1)
        cmd_play(args.playlist_name, args.name)

if __name__ == "__main__":
    main()
