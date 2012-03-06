""" Author: Maximilian Nickel
""" Version: 0.3
""" License: http://www.opensource.org/licenses/bsd-license.php

" Description: {{{
"   This plugin opens the Mac OS X color picker and inserts
"   the choosen color at the current position.
"   Either Hex values or raw RGB values are supported
" }}}

" Don't load script when already loaded
" or when not on mac

if exists("g:loaded_colorchooser") || !has('mac')
  finish
endif
let g:loaded_colorchooser = 1

let s:app = 'Terminal.app'
if has('gui_macvim')
  let s:app = 'MacVim.app'
endif

let s:ascrpt = ['-e "tell application \"' . s:app . '\""', 
      \ '-e "activate"', 
      \ "-e \"set AppleScript's text item delimiters to {\\\",\\\"}\"",
      \ '-e "set col to (choose color', 
      \ '',
      \ ') as text"',
      \ '-e "end tell"']

function! s:parse_html_color()
  let w = expand("<cword>")
  if w =~ '#\([a-fA-F1-9]\{3,6\}\)'
    let offset = 2
    let mult = 256
    if len(w) == 4
      let offset = 1
      let mult = mult * 17
    endif
    let cr = str2nr(strpart(w,1,offset), 16) * mult
    let cg = str2nr(strpart(w,1+offset,offset), 16) * mult
    let cb = str2nr(strpart(w,1+2*offset,offset), 16) * mult
    return printf('default color {%d,%d,%d}', cr, cg, cb) 
  endif
  return ''
endfunction

function! s:colour_rgb()
  let lst = remove(s:ascrpt, 4)
  return system("osascript " . join(insert(s:ascrpt, s:parse_html_color(), 4), ' '))
endfunction

function! s:append_colour(col)
  exe "normal a" . a:col
endfunction

function! s:colour_hex()
  let rgb = split(s:colour_rgb(), ',')
  return printf('#%02X%02X%02X', str2nr(rgb[0])/256, str2nr(rgb[1])/256, str2nr(rgb[2])/256)
endfunction

command! ColorRGB :call s:append_colour(s:colour_rgb())
command! ColorHEX :call s:append_colour(s:colour_hex())
