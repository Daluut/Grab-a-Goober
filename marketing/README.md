# Grab a Goober - marketing assets

- `GrabAGoober_Trailer.mp4` - 10 s trailer, 1920x1080, 30 fps, H.264 + AAC (with a synthesized, royalty-free jingle)
- `thumbnails/` - 1920x1080 experience thumbnails
- `icons/` - 512x512 experience icons

Everything is drawn in code (`src/art.js` = characters, `src/scenes.js` = trailer cutscenes / thumbnails / icons),
so it can be re-rendered or tweaked. Fonts in `fonts/` are Google Fonts (SIL Open Font License).

Re-render (needs Node + Playwright's Chromium; ffmpeg for the video):
    cd src && node render.js thumb 1 ../thumbnails/Thumbnail_1.png
    cd src && node render.js icon 2 ../icons/Icon_2.png
    cd src && node render.js trailer 1 <frames-dir> 300 30   # then ffmpeg the PNGs + trailer_music.wav (python3 music.py)
