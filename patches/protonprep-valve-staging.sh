#!/bin/bash

# patch functions
apply_patch() {
    local patch_path="$1"
    patch -Np1 < "$patch_path"
}

apply_all_in_dir() {
    local dir="$1"
    for patch in "$dir"/*.patch; do
        apply_patch "$patch"
    done
}

### (1) PREP SECTION ###

    pushd dxvk
    git reset --hard HEAD
    git clean -xdf
    popd

    pushd vkd3d-proton
    git reset --hard HEAD
    git clean -xdf
    popd

    pushd dxvk-nvapi
    git reset --hard HEAD
    git clean -xdf
    popd

    pushd gstreamer
    git reset --hard HEAD
    git clean -xdf
    echo "GSTREAMER: fix for unclosable invisible wayland opengl windows in taskbar"
    apply_all_in_dir "../patches/gstreamer/"
    popd

    pushd protonfixes
    git reset --hard HEAD
    git clean -xdf
    pushd subprojects
    pushd libmspack
    git reset --hard HEAD
    git clean -xdf
    popd
    pushd umu-database
    git reset --hard HEAD
    git clean -xdf
    popd
    pushd unzip
    git reset --hard HEAD
    git clean -xdf
    popd
    pushd winetricks
    git reset --hard HEAD
    git clean -xdf
    echo "WINETRICKS: fix broken gnutls when fetching https"
    apply_patch "../../../patches/winetricks/winetrick_gnutls_fix.patch"
    echo "WINETRICKS: fix broken mono/dotnet removal"
    apply_patch "../../../patches/winetricks/winetricks_dotnet_remove_fix.patch"
    popd
    popd
    popd

### END PREP SECTION ###

### (2) WINE PATCHING ###

    pushd wine
    git reset --hard HEAD
    git clean -xdf

### (2-1) PROBLEMATIC COMMIT REVERT SECTION ###

# Bring back configure files. Staging uses them to regenerate fresh ones
# https://github.com/ValveSoftware/wine/commit/e813ca5771658b00875924ab88d525322e50d39f

    git revert --no-commit e813ca5771658b00875924ab88d525322e50d39f

# This doesn't correctly resolve the issue. We have patches that handle this for gstreamer
# Need to revert this so our patches work.

    git revert --no-commit 37818f7a547f7090ef684f8202438374fc31a165

### END PROBLEMATIC COMMIT REVERT SECTION ###


### (2-2) WINE STAGING APPLY SECTION ###

    echo "WINE: -STAGING- applying staging patches"

    ../wine-staging/staging/patchinstall.py DESTDIR="." --all --no-autoconf\
    -W winex11-_NET_ACTIVE_WINDOW \
    -W winex11-WM_WINDOWPOSCHANGING \
    -W user32-alttab-focus \
    -W winex11-MWM_Decorations \
    -W server-Signal_Thread \
    -W ntdll-Junction_Points \
    -W server-Stored_ACLs \
    -W server-File_Permissions \
    -W kernel32-CopyFileEx \
    -W shell32-Progress_Dialog \
    -W shell32-ACE_Viewer \
    -W dbghelp-Debug_Symbols \
    -W ntdll-Syscall_Emulation \
    -W eventfd_synchronization \
    -W server-PeekMessage \
    -W server-Realtime_Priority \
    -W msxml3-FreeThreadedXMLHTTP60 \
    -W ntdll-ForceBottomUpAlloc \
    -W ntdll-NtDevicePath \
    -W ntdll_reg_flush \
    -W user32-rawinput-mouse \
    -W user32-recursive-activation \
    -W d3dx11_43-D3DX11CreateTextureFromMemory \
    -W d3dx9_36-D3DXStubs \
    -W wined3d-zero-inf-shaders \
    -W ntdll-RtlQueryPackageIdentity \
    -W loader-KeyboardLayouts \
    -W ntdll-Hide_Wine_Exports \
    -W kernel32-Debugger \
    -W ntdll-ext4-case-folder \
    -W user32-FlashWindowEx \
    -W winex11-Fixed-scancodes \
    -W winex11-Window_Style \
    -W winex11-ime-check-thread-data \
    -W winex11.drv-Query_server_position \
    -W wininet-Cleanup \
    -W cryptext-CryptExtOpenCER \
    -W wineboot-ProxySettings \
    -W version-VerQueryValue \
    -W setupapi-DiskSpaceList

    # NOTE: Some patches are applied manually because they -do- apply, just not cleanly, ie with patch fuzz.
    # A detailed list of why the above patches are disabled is listed below:

    # winex11-_NET_ACTIVE_WINDOW - Causes origin to freeze
    # winex11-WM_WINDOWPOSCHANGING - Causes origin to freeze
    # user32-alttab-focus - relies on winex11-_NET_ACTIVE_WINDOW -- may be able to be added now that EA Desktop has replaced origin?
    # winex11-MWM_Decorations - not compatible with fullscreen hack
    # server-Signal_Thread - breaks steamclient for some games -- notably DBFZ
    # ntdll-Junction_Points - breaks CEG drm
    # server-Stored_ACLs - requires ntdll-Junction_Points
    # server-File_Permissions - requires ntdll-Junction_Pointsv
    # kernel32-CopyFileEx - breaks various installers
    # shell32-Progress_Dialog - relies on kernel32-CopyFileEx
    # shell32-ACE_Viewer - adds a UI tab, not needed, relies on kernel32-CopyFileEx
    # dbghelp-Debug_Symbols - Ubisoft Connect games (3/3 I had installed and could test) will crash inside pe_load_debug_info function with this enabled

    # ntdll-Syscall_Emulation - already applied
    # eventfd_synchronization - already applied
    # server-PeekMessage - already applied
    # server-Realtime_Priority - already applied
    # msxml3-FreeThreadedXMLHTTP60 - already applied
    # ntdll-ForceBottomUpAlloc - already applied
    # ntdll-NtDevicePath - already applied
    # ntdll_reg_flush - already applied
    # user32-rawinput-mouse - already applied
    # user32-recursive-activation - already applied
    # d3dx11_43-D3DX11CreateTextureFromMemory - already applied
    # d3dx9_36-D3DXStubs - already applied
    # wined3d-zero-inf-shaders - already applied
    # ntdll-RtlQueryPackageIdentity - already applied
    # version-VerQueryValue - just a test and doesn't apply cleanly. not relevant for gaming

    # applied manually:
    # ** loader-KeyboardLayouts - note -- always use and/or rebase this --  needed to prevent Overwatch huge FPS drop
    # ntdll-Hide_Wine_Exports
    # kernel32-Debugger
    # ntdll-ext4-case-folder
    # user32-FlashWindowEx
    # winex11-Fixed-scancodes
    # winex11-Window_Style
    # winex11-ime-check-thread-data
    # winex11.drv-Query_server_position
    # wininet-Cleanup

    # rebase and applied manually:
    # ** loader-KeyboardLayouts - note -- always use and/or rebase this --  needed to prevent Overwatch huge FPS drop
    # cryptext-CryptExtOpenCER
    # wineboot-ProxySettings

    # dinput-joy-mappings - disabled in favor of proton's gamepad patches -- currently also disabled in upstream staging
    # mfplat-streaming-support -- interferes with proton's mfplat -- currently also disabled in upstream staging
    # wined3d-SWVP-shaders -- interferes with proton's wined3d -- currently also disabled in upstream staging
    # wined3d-Indexed_Vertex_Blending -- interferes with proton's wined3d -- currently also disabled in upstream staging
    # setupapi-DiskSpaceList -- upstream commits were brought in for dualsense fixes, the staging patches are no longer needed

    echo "WINE: -STAGING- loader-KeyboardLayouts manually applied"
    apply_all_in_dir "../wine-staging/patches/loader-KeyboardLayouts/"

    echo "WINE: -STAGING- ntdll-Hide_Wine_Exports manually applied"
    apply_all_in_dir "../wine-staging/patches/ntdll-Hide_Wine_Exports/"

    echo "WINE: -STAGING- kernel32-Debugger manually applied"
    apply_all_in_dir "../wine-staging/patches/kernel32-Debugger/"

    echo "WINE: -STAGING- ntdll-ext4-case-folder manually applied"
    apply_all_in_dir "../wine-staging/patches/ntdll-ext4-case-folder/"

    echo "WINE: -STAGING- user32-FlashWindowEx manually applied"
    apply_all_in_dir "../wine-staging/patches/user32-FlashWindowEx/"

    echo "WINE: -STAGING- winex11-Fixed-scancodes manually applied"
    apply_all_in_dir "../wine-staging/patches/winex11-Fixed-scancodes/"

    echo "WINE: -STAGING- winex11-Window_Style manually applied"
    apply_all_in_dir "../wine-staging/patches/winex11-Window_Style/"

    echo "WINE: -STAGING- winex11-ime-check-thread-data manually applied"
    apply_all_in_dir "../wine-staging/patches/winex11-ime-check-thread-data/"

    echo "WINE: -STAGING- winex11.drv-Query_server_position manually applied"
    apply_all_in_dir "../wine-staging/patches/winex11.drv-Query_server_position/"

    echo "WINE: -STAGING- wininet-Cleanup manually applied"
    apply_all_in_dir "../wine-staging/patches/wininet-Cleanup/"

    echo "WINE: -STAGING- cryptext-CryptExtOpenCER manually applied"
    apply_all_in_dir "../patches/wine-hotfixes/staging/cryptext-CryptExtOpenCER/"

    echo "WINE: -STAGING- wineboot-ProxySettings manually applied"
    apply_all_in_dir "../patches/wine-hotfixes/staging/wineboot-ProxySettings/"


### END WINE STAGING APPLY SECTION ###

### (2-3) GAME PATCH SECTION ###

    echo "WINE: -GAME FIXES- assetto corsa hud fix"
    apply_patch "../patches/game-patches/assettocorsa-hud.patch"

    echo "WINE: -GAME FIXES- add file search workaround hack for Phantasy Star Online 2 (WINE_NO_OPEN_FILE_SEARCH)"
    apply_patch "../patches/game-patches/pso2_hack.patch"

    echo "WINE: -GAME FIXES- add set current directory workaround for Vanguard Saga of Heroes"
    apply_patch "../patches/game-patches/vgsoh.patch"

    echo "WINE: -GAME FIXES- add xinput support to Dragon Age Inquisition"
    apply_patch "../patches/game-patches/dai_xinput.patch"

    echo "WINE: -GAME FIXES- add unsupported os popup fix for star citizen"
    apply_patch "../patches/game-patches/silence-starcitizen-unsupported-os.patch"

    # https://github.com/JacKeTUs/wine/commits/lmu-d2d1-tinkering
    echo "WINE: -GAME FIXES- add le mans ultimate patches"
    apply_patch "../patches/game-patches/lemansultimate-gameinput.patch"

### END GAME PATCH SECTION ###

### (2-4) WINE HOTFIX/BACKPORT SECTION ###

### END WINE HOTFIX/BACKPORT SECTION ###

### (2-5) WINE PENDING UPSTREAM SECTION ###

    # https://github.com/Frogging-Family/wine-tkg-git/commit/ca0daac62037be72ae5dd7bf87c705c989eba2cb
    echo "WINE: -PENDING- unity crash hotfix"
    apply_patch "../patches/wine-hotfixes/pending/unity_crash_hotfix.patch"

    # https://bugs.winehq.org/show_bug.cgi?id=58476
    echo "WINE: -PENDING- RegGetValueW dwFlags hotfix (R.E.A.L VR mod)"
    apply_patch "../patches/wine-hotfixes/pending/registry_RRF_RT_REG_SZ-RRF_RT_REG_EXPAND_SZ.patch"

    # https://github.com/ValveSoftware/wine/pull/205
    # https://github.com/ValveSoftware/Proton/issues/4625
    echo "WINE: -PENDING- Add WINE_DISABLE_SFN option. (Yakuza 5 cutscenes fix)"
    apply_patch "../patches/wine-hotfixes/pending/ntdll_add_wine_disable_sfn.patch"

    echo "WINE: -PENDING- ncrypt: NCryptDecrypt implementation (PSN Login for Ghost of Tsushima)"
    apply_patch "../patches/wine-hotfixes/pending/NCryptDecrypt_implementation.patch"

    #https://github.com/GloriousEggroll/proton-ge-custom/issues/283
    echo "WINE: -PENDING- quartz: backport to allow clannad videos to work"
    apply_patch "../patches/wine-hotfixes/pending/8848.patch"

### END WINE PENDING UPSTREAM SECTION ###

### (2-5.1) WINE-GST PROTON RTSP SECTION ###

    echo "WINE: -WINE-GST- applying RTSP and GStreamer related patches"

    echo "WINE: -WINE-GST- 0001-mfmediaengine-Implement-IMFMediaEngine-IsSeeking.patch"
    apply_patch "../patches/wine-gst/0001-mfmediaengine-Implement-IMFMediaEngine-IsSeeking.patch"

    echo "WINE: -WINE-GST- 0002-AVPro-Video-seeking-support.patch"
    apply_patch "../patches/wine-gst/0002-AVPro-Video-seeking-support.patch"

    echo "WINE: -WINE-GST- 0003-quartz-Fix-buffer-overflow-when-passing-url-as-filen.patch"
    apply_patch "../patches/wine-gst/0003-quartz-Fix-buffer-overflow-when-passing-url-as-filen.patch"

    echo "WINE: -WINE-GST- 0004-winegstreamer-Initialize-condition-variable-of-struc.patch"
    apply_patch "../patches/wine-gst/0004-winegstreamer-Initialize-condition-variable-of-struc.patch"

    echo "WINE: -WINE-GST- 0005-winegstreamer-Do-not-create-a-read-thread-for-uridec.patch"
    apply_patch "../patches/wine-gst/0005-winegstreamer-Do-not-create-a-read-thread-for-uridec.patch"

    echo "WINE: -WINE-GST- 0006-winegstreamer-Add-more-RTSP-based-URI-schemes-to-GSt.patch"
    apply_patch "../patches/wine-gst/0006-winegstreamer-Add-more-RTSP-based-URI-schemes-to-GSt.patch"

    echo "WINE: -WINE-GST- 0007-winegstreamer-Mark-wg_parser-container-bin-as-stream.patch"
    apply_patch "../patches/wine-gst/0007-winegstreamer-Mark-wg_parser-container-bin-as-stream.patch"

    echo "WINE: -WINE-GST- 0008-winegstreamer-Set-a-clock-for-the-wg_parser-pipeline.patch"
    apply_patch "../patches/wine-gst/0008-winegstreamer-Set-a-clock-for-the-wg_parser-pipeline.patch"

    echo "WINE: -WINE-GST- 0009-winegstreamer-Set-base-time-on-wg_parser-bin-while-c.patch"
    apply_patch "../patches/wine-gst/0009-winegstreamer-Set-base-time-on-wg_parser-bin-while-c.patch"

    echo "WINE: -WINE-GST- 0010-winegstreamer-Put-pipeline-into-PLAYING-state-before.patch"
    apply_patch "../patches/wine-gst/0010-winegstreamer-Put-pipeline-into-PLAYING-state-before.patch"

    echo "WINE: -WINE-GST- 0011-winegstreamer-Handle-a-duration-of-1-correctly.patch"
    apply_patch "../patches/wine-gst/0011-winegstreamer-Handle-a-duration-of-1-correctly.patch"

    echo "WINE: -WINE-GST- 0012-winegstreamer-Convert-buffer-presentation-timestamps.patch"
    apply_patch "../patches/wine-gst/0012-winegstreamer-Convert-buffer-presentation-timestamps.patch"

    echo "WINE: -WINE-GST- 0013-winegstreamer-Reorder-parser-initialization-code-a-b.patch"
    apply_patch "../patches/wine-gst/0013-winegstreamer-Reorder-parser-initialization-code-a-b.patch"

    echo "WINE: -WINE-GST- 0014-winegstreamer-Do-away-with-the-per-stream-condvars-a.patch"
    apply_patch "../patches/wine-gst/0014-winegstreamer-Do-away-with-the-per-stream-condvars-a.patch"

    echo "WINE: -WINE-GST- 0015-winegstreamer-Use-pthread_cond_broadcast-instead-of-.patch"
    apply_patch "../patches/wine-gst/0015-winegstreamer-Use-pthread_cond_broadcast-instead-of-.patch"

    echo "WINE: -WINE-GST- 0016-winegstreamer-Do-not-fail-caps-negotiation-when-ther.patch"
    apply_patch "../patches/wine-gst/0016-winegstreamer-Do-not-fail-caps-negotiation-when-ther.patch"

    echo "WINE: -WINE-GST- 0017-winegstreamer-Do-not-seek-live-sources.patch"
    apply_patch "../patches/wine-gst/0017-winegstreamer-Do-not-seek-live-sources.patch"

    echo "WINE: -WINE-GST- 0018-winegstreamer-Assume-server-does-not-support-ranges-.patch"
    apply_patch "../patches/wine-gst/0018-winegstreamer-Assume-server-does-not-support-ranges-.patch"

    echo "WINE: -WINE-GST- 0019-winegstreamer-Implement-buffering-events.patch"
    apply_patch "../patches/wine-gst/0019-winegstreamer-Implement-buffering-events.patch"

    echo "WINE: -WINE-GST- 0020-mf-samplegrabber-Send-sample-requests-for-unused-spa.patch"
    apply_patch "../patches/wine-gst/0020-mf-samplegrabber-Send-sample-requests-for-unused-spa.patch"

    echo "WINE: -WINE-GST- 0021-winegstreamer-Do-waits-for-samples-on-stream-specifi.patch"
    apply_patch "../patches/wine-gst/0021-winegstreamer-Do-waits-for-samples-on-stream-specifi.patch"

    echo "WINE: -WINE-GST- 0022-mf-session-Ensure-that-the-command-callback-does-not.patch"
    apply_patch "../patches/wine-gst/0022-mf-session-Ensure-that-the-command-callback-does-not.patch"

    echo "WINE: -WINE-GST- 0023-winegstreamer-Also-flush-token-queue-on-seek.patch"
    apply_patch "../patches/wine-gst/0023-winegstreamer-Also-flush-token-queue-on-seek.patch"

    echo "WINE: -WINE-GST- 0024-mf-session-Fix-pausing-a-media-session-when-the-medi.patch"
    apply_patch "../patches/wine-gst/0024-mf-session-Fix-pausing-a-media-session-when-the-medi.patch"

    echo "WINE: -WINE-GST- 0025-winegstreamer-Do-not-force-uridecodebin-to-expose-un.patch"
    apply_patch "../patches/wine-gst/0025-winegstreamer-Do-not-force-uridecodebin-to-expose-un.patch"

    echo "WINE: -WINE-GST- 0026-mfmediaengine-Unstub-IMFMediaEngine-SetAutoPlay.patch"
    apply_patch "../patches/wine-gst/0026-mfmediaengine-Unstub-IMFMediaEngine-SetAutoPlay.patch"

    echo "WINE: -WINE-GST- 0027-mfmediaengine-Allow-video_frame_sink-to-continue-to-.patch"
    apply_patch "../patches/wine-gst/0027-mfmediaengine-Allow-video_frame_sink-to-continue-to-.patch"

    echo "WINE: -WINE-GST- 0028-mfmediaengine-Fix-crash-when-playing-audio-only-sour.patch"
    apply_patch "../patches/wine-gst/0028-mfmediaengine-Fix-crash-when-playing-audio-only-sour.patch"

    echo "WINE: -WINE-GST- 0029-winegstreamer-Ignore-closed-caption-streams.patch"
    apply_patch "../patches/wine-gst/0029-winegstreamer-Ignore-closed-caption-streams.patch"

    echo "WINE: -WINE-GST- 0030-HACK-winegstreamer-Add-a-resampler-to-wg_parser-for-.patch"
    apply_patch "../patches/wine-gst/0030-HACK-winegstreamer-Add-a-resampler-to-wg_parser-for-.patch"

    echo "WINE: -WINE-GST- 0031-HACK-winegstreamer-Add-a-videoscale-element-to-wg_pa.patch"
    apply_patch "../patches/wine-gst/0031-HACK-winegstreamer-Add-a-videoscale-element-to-wg_pa.patch"

    echo "WINE: -WINE-GST- 0032-HACK-mfmediaengine-Do-not-send-MF_MEDIA_ENGINE_EVENT.patch"
    apply_patch "../patches/wine-gst/0032-HACK-mfmediaengine-Do-not-send-MF_MEDIA_ENGINE_EVENT.patch"

    echo "WINE: -WINE-GST- 0033-TODO-SQUASH-winegstreamer-Fix-hang-during-media-sour.patch"
    apply_patch "../patches/wine-gst/0033-TODO-SQUASH-winegstreamer-Fix-hang-during-media-sour.patch"

    echo "WINE: -WINE-GST- 0034-TODO-SQUASH-mf-Fix-presentation-clock-starting-at-wr.patch"
    apply_patch "../patches/wine-gst/0034-TODO-SQUASH-mf-Fix-presentation-clock-starting-at-wr.patch"

    echo "WINE: -WINE-GST- 0035-Marker-commit-do-not-put-into-MR.patch"
    apply_patch "../patches/wine-gst/0035-Marker-commit-do-not-put-into-MR.patch"

    echo "WINE: -WINE-GST- 0036-ntdll-Use-unixcall-instead-of-syscall-for-QueryPerfo.patch"
    apply_patch "../patches/wine-gst/0036-ntdll-Use-unixcall-instead-of-syscall-for-QueryPerfo.patch"

    echo "WINE: -WINE-GST- 0037-mfplat-Allocate-memory-buffers-using-calloc.patch"
    apply_patch "../patches/wine-gst/0037-mfplat-Allocate-memory-buffers-using-calloc.patch"

    echo "WINE: -WINE-GST- 0038-DEBUG-winegstreamer-GST_LOG-GST_DEBUG.patch"
    apply_patch "../patches/wine-gst/0038-DEBUG-winegstreamer-GST_LOG-GST_DEBUG.patch"

    echo "WINE: -WINE-GST- 0039-HACK-kernelbase-yt-dlp.exe-redirection-and-cmdline-m.patch"
    apply_patch "../patches/wine-gst/0039-HACK-kernelbase-yt-dlp.exe-redirection-and-cmdline-m.patch"

    echo "WINE: -WINE-GST- 0040-mf-Schedule-stored-timers-for-the-original-time-inst.patch"
    apply_patch "../patches/wine-gst/0040-mf-Schedule-stored-timers-for-the-original-time-inst.patch"

    echo "WINE: -WINE-GST- 0041-mf-Start-forwarding-samples-only-at-the-PTS-of-the-f.patch"
    apply_patch "../patches/wine-gst/0041-mf-Start-forwarding-samples-only-at-the-PTS-of-the-f.patch"

    echo "WINE: -WINE-GST- 0042-HACK-kernelbase-Replace-stderr-of-yt-dlp-process.patch"
    apply_patch "../patches/wine-gst/0042-HACK-kernelbase-Replace-stderr-of-yt-dlp-process.patch"

    echo "WINE: -WINE-GST- 0043-TODO-SQUASH-kernelbase-Remove-PROTON_YTDLP_BROWSER-h.patch"
    apply_patch "../patches/wine-gst/0043-TODO-SQUASH-kernelbase-Remove-PROTON_YTDLP_BROWSER-h.patch"

    echo "WINE: -WINE-GST- 0044-wip.patch"
    apply_patch "../patches/wine-gst/0044-wip.patch"

    echo "WINE: -WINE-GST- 0045-wip2.patch"
    apply_patch "../patches/wine-gst/0045-wip2.patch"

    echo "WINE: -WINE-GST- 0046-wip3.patch"
    apply_patch "../patches/wine-gst/0046-wip3.patch"

    echo "WINE: -WINE-GST- 0047-revert-disable-some-stuff.patch"
    apply_patch "../patches/wine-gst/0047-revert-disable-some-stuff.patch"

    echo "WINE: -WINE-GST- 0048-ntdll-unix-Reset-MXCSR-to-the-default-value-on-exit-.patch"
    apply_patch "../patches/wine-gst/0048-ntdll-unix-Reset-MXCSR-to-the-default-value-on-exit-.patch"

### END WINE-GST PROTON RTSP SECTION ###


### (2-6) PROTON-GE ADDITIONAL CUSTOM PATCHES ###

    echo "WINE: -FSR- fullscreen hack fsr patch"
    apply_patch "../patches/proton/0001-fshack-Implement-AMD-FSR-upscaler-for-fullscreen-hac.patch"

    echo "WINE: -Nvidia Reflex- Support VK_NV_low_latency2"
    apply_patch "../patches/proton/83-nv_low_latency_wine.patch"

    echo "WINE: -CUSTOM- Add nls to tools"
    apply_patch "../patches/proton/build_failure_prevention-add-nls.patch"

    echo "WINE: -CUSTOM Add options to disable proton media converter."
    apply_patch "../patches/proton/add-envvar-to-gate-media-converter.patch"

    echo "WINE: -CUSTOM- Downgrade MESSAGE to TRACE to remove write_watches spam"
    apply_patch "../patches/proton/0001-ntdll-Downgrade-using-kernel-write-watches-from-MESS.patch"

    echo "WINE: -CUSTOM- Add WINE_NO_WM_DECORATION option to disable window decorations so that borders behave properly"
    apply_patch "../patches/proton/0001-win32u-add-env-switch-to-disable-wm-decorations.patch"

    echo "WINE: -CUSTOM- Fix a crash in ID2D1DeviceContext if no target is set"
    apply_patch "../patches/proton/fix-a-crash-in-ID2D1DeviceContext-if-no-target-is-set.patch"

    echo "WINE: -CUSTOM- Add envvar to allow method=automatic to be set for video orientation in gstreamer"
    apply_patch "../patches/proton/proton-use_winegstreamer_and_set_orientation-PROTON_MEDIA_USE_GST-PROTON_GST_VIDEO_ORIENTATION.patch"

    echo "WINE: -CUSTOM- ETASSH WINE-WAYLAND+ PATCHES"
    apply_all_in_dir "../patches/wine-hotfixes/wine-wayland/"

    echo "WINE: RUN AUTOCONF TOOLS/MAKE_REQUESTS"
    autoreconf -f
    ./tools/make_requests

    popd



### END PROTON-GE ADDITIONAL CUSTOM PATCHES ###
### END WINE PATCHING ###
