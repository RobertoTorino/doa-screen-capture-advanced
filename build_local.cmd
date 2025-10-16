@echo off
title Building AHK Script
powershell -NoExit -ExecutionPolicy Bypass -Command "& '%~dp0build_local.ps1'"
