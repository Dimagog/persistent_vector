@echo off

setlocal ENABLEDELAYEDEXPANSION
if "%diff%" == "" set diff=fc

call mix run bench\bench.exs %* >b

if exist a (
  call %diff% a b
  set /P better=Is 'b' better [y/N]? 
  if /I "!better!" == "y" (
    echo New base 'a'
    move /Y b a >nul
  )
) else (
  echo Established base 'a'
  move /Y b a >nul
  call %diff% benchmarks.md a
)
