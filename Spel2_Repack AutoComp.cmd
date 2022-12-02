@echo off

set sfx-optimize=-optimize_samplerate

set scriptpath=%~dp0
cd %scriptpath%

set sfx_size_test=0
set music_size_test=0

set default_sfx_size=195978200
set default_music_size=1768422200

set sfx_quality=0
set music_quality=0

REM this is used for misc temp data
set temp_walker=0


:Setup
set /p audio_quality=OGG Quality 1-100 or (a) for auto: 

REM Checks to make sure audio_quality is a valid input
REM If not, it will be set to auto

REM Checks for null
IF "%audio_quality%" == "" set audio_quality=a &echo That was not an input, auto has been selected. &echo.
REM Sets temp to 0 if not a number
set /a temp_walker=%audio_quality%+0
IF %temp_walker% EQU 0 (
    IF %audio_quality% NEQ a set audio_quality=a &echo That was not a valid input, auto has been selected. &echo.
) ELSE (
    IF %audio_quality% GTR 100 set audio_quality=a &echo That value was too high, auto has been selected. &echo.
    IF %audio_quality% LSS 1 set audio_quality=a &echo That value was too low, auto has been selected. &echo.
)



:AUDIOFILES-CHECK
REM Checking if all folders exist

IF NOT EXIST "Repack\FSB5" mkdir "Repack\FSB5"
IF NOT EXIST "Extracted\Soundbank\soundbank.bank" echo The original Soundbank file is missing! &echo. &pause &exit
IF NOT EXIST "Extracted\SFX\SFX.lst" echo The extracted SFX's .lst file is missing! &echo. &pause &exit
IF NOT EXIST "Extracted\MUSIC\MUSIC.lst" echo The extracted MUSIC's .lst file is missing! &echo. &pause &exit

REM Checking if all audio files listed in both sfx and music .lst exist inside the extracted folders

set missing-sfx=0
set missing-music=0

pushd "Extracted\SFX"
echo Checking SFX files inside "Extracted\SFX"... &echo.
for /f "delims=" %%A in (SFX.lst) do set /a sfx_size_test+=%%~zA &(IF NOT EXIST %%A echo The file "%%A" is missing! &set missing-sfx=1)
IF %missing-sfx% EQU 1 echo. &echo Some SFX files are missing inside "Extracted\SFX" &echo You need to have all the files to be able to repack! &echo. &pause &exit
popd

pushd "Extracted\MUSIC"
echo Checking MUSIC files inside "Extracted\MUSIC"... &echo.
for /f "delims=" %%A in (MUSIC.lst) do set /a music_size_test+=%%~zA &(IF NOT EXIST %%A echo The file "%%A" is missing! &set missing-music=1)
IF %missing-music% EQU 1 echo. &echo Some MUSIC files are missing inside "Extracted\MUSIC" &echo You need to have all the files to be able to repack! &echo. &pause &exit
popd



:QUALITY-SET
REM Sets sound quality auto or non auto
REM First compares current size of sfx to vanilla
set /a "temp_walker=%sfx_size_test%-%default_sfx_size%"
echo %temp_walker% is the sfx data increase in bytes
REM The sfx hardly gets compressed lol
IF %audio_quality% EQU a set /a "sfx_quality=(100 - (%sfx_size_test% - %default_sfx_size%)/100000000)"
REM make sure the final calculation is in valid range when echoing
IF %sfx_quality% GTR 100 set sfx_quality=100
IF %sfx_quality% LSS 1 set sfx_quality=1
IF %audio_quality% NEQ a (IF %audio_quality% NEQ m set sfx_quality=%audio_quality%)
echo the final sfx quality is %sfx_quality% &echo.

REM Sets music quality auto or non auto
REM First compares current size of music to vanilla
set /a "temp_walker=%music_size_test%-%default_music_size%"
echo %temp_walker% is the music data increase in bytes
REM The music math is pretty good now :)
IF %audio_quality% EQU a set /a "music_quality=(65 - (%music_size_test% - %default_music_size%)/350000)"
REM make sure the final calculation is in valid range when echoing
IF %music_quality% GTR 100 set music_quality=100
IF %music_quality% LSS 1 set music_quality=1
IF %audio_quality% NEQ a (IF %audio_quality% NEQ m set music_quality=%audio_quality%)
echo the final music quality is %music_quality% &echo.



:REPACK-SFX
REM Use Fsbank to generate a new .fsb file from the sfx files list created during the extraction process
REM The optimize parameter will compress the sfx .fsb file to allow more space for the modified sound files

IF EXIST "Repack\FSB5\00000000.fsb" echo Warning, this will override the old repacked SFX! &timeout /T 5

API-Fmod\fsbankcl.exe -rebuild -format vorbis -quality %sfx_quality% -o "Repack\FSB5\00000000.fsb" "Extracted\SFX\SFX.lst"

REM Making sure that the new sfx .fsb file is not bigger than the extracted one
FOR %%I in (Extracted\FSB5\00000000.fsb) do set size-sfx-ext=%%~zI
FOR %%I in (Repack\FSB5\00000000.fsb) do set size-sfx-rep=%%~zI
IF %size-sfx-rep% GTR %size-sfx-ext% echo. &echo THE NEW SFX .FSB FILE IS TOO BIG! &echo You need to reduce the size of your modified sfx files! &echo You can also try lowering the ogg quality when repacking. &echo. &goto Setup



:REPACK-MUSIC
REM Use Fsbank to generate a new .fsb file from the music files list created during the extraction process
REM The music files are compressed to vorbis, you can lower the quality value to make the music .fsb file smaller (71 will get it just under the original size)

IF EXIST "Repack\FSB5\00000001.fsb" echo. &echo Warning, this will override the old repacked MUSIC! &timeout /T 5

API-Fmod\fsbankcl.exe -rebuild -format vorbis -quality %music_quality% -o "Repack\FSB5\00000001.fsb" "Extracted\MUSIC\MUSIC.lst"

REM Making sure that the new music .fsb file is not bigger than the extracted one
FOR %%I in (Extracted\FSB5\00000001.fsb) do set size-music-ext=%%~zI
FOR %%I in (Repack\FSB5\00000001.fsb) do set size-music-rep=%%~zI
IF %size-music-rep% GTR %size-music-ext% echo. &echo THE NEW MUSIC .FSB FILE IS TOO BIG! &echo You need to reduce the size of your modified music files! &echo You can also try lowering the ogg quality when repacking. &echo. &goto Setup



:REPACK-SOUNDBANK
REM Use QuickBMS to reinject the new .fsb files into the original soundbank
REM Both .fsb files need to be smaller or the same size than before, otherwise QuickBMS cannot inject them back

echo.
IF NOT EXIST "Repack\Soundbank" mkdir "Repack\Soundbank"
IF NOT EXIST "Repack\FSB5\00000000.fsb" echo The SFX .fsb file is missing! &echo. &pause &exit
IF NOT EXIST "Repack\FSB5\00000001.fsb" echo The MUSIC .fsb file is missing! &echo. &pause &exit
IF EXIST "Repack\Soundbank\soundbank.bank" echo Warning, this will override the old repacked soundbank! &timeout /T 5 &echo.

copy "%scriptpath%Extracted\Soundbank\soundbank.bank" "%scriptpath%Repack\Soundbank\" /Y &timeout /T 5 >NUL
quickbms.exe -w -r FSB5.bms Repack\Soundbank\soundbank.bank Repack\FSB5\



:END
echo. &pause