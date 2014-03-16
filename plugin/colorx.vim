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

" Formats: HEX, RGBCSS, RGB100

if exists("g:loaded_colorchooser") || !has('mac')
  finish
endif
let g:loaded_colorchooser = 1

if !exists("g:colorpicker_app")
  let g:colorpicker_app = 'Terminal.app'
  if has('gui_macvim')
    let g:colorpicker_app = 'MacVim.app'
  endif
endif

let s:ascrpt = ['-e "tell application \"' . g:colorpicker_app . '\""',
      \ '-e "activate"',
      \ "-e \"set AppleScript's text item delimiters to {\\\",\\\"}\"",
      \ '-e "set col to (choose color',
      \ '',
      \ ') as text"',
      \ '-e "end tell"']

" Get cursor color in HEX format
function! s:parse_hex_color(colour)
  if a:colour[0] != ''
    return a:colour
  end
  let w = a:colour[0]
  let line = getline('.')
  let col = col('.')
  let start_col = 0
  let pattern = '#\([a-fA-F0-9]\{3,8\}\)'
  while 1
    let start = match(line, pattern, start_col)
    let end = matchend(line, pattern, start_col)
    if start > -1
      if col >= start + 1 && col <= end
        return [matchstr(line, pattern, start_col), start, end, 'HEX', '']
        break
      end
      let start_col = end
    else
      break
    end
  endwhile
  return ['', col, col, '', '']
endfunction

" Convert dec value to HEX
function! s:parse_dec_val(val)
  if a:val =~ '^-\?[12]\?[0-9]\{1,2\}$'
    let val = str2nr(a:val, 10)
    let val = max([0, val])
    let val = min([255, val])
    return printf('%02x', val)
  else
    return a:val
  end
endfunction

" Convert dec alpha value to HEX
function! s:parse_dec_alpha_val(val)
  if a:val =~ '^-\?[0-9\.]\+$'
    let val = str2float(a:val)
    if val > 1
      let val = 1
    elseif val < 0
      let val = 0
    end
    return printf('%02x', float2nr(val*255))
  else
    return a:val
  end
endfunction

" Convert percent value to HEX
" return [color, start, end]
function! s:parse_percent_val(val)
  if a:val =~ '^-\?[0-9\.]\+%$'
    let val = strpart(a:val, 0, len(a:val) - 1)
    let val = float2nr( str2float(val) * 2.55 )
    let val = max([0, val])
    let val = min([255, val])
    return printf('%02x', val)
  else
    return a:val
  end
endfunction

" Conver RGB value to HEX
function! s:parse_rgb_val(val)
  let val = a:val
  let val = substitute(val, '^ \+', '', '')
  let val = substitute(val, ' \+$', '', '')
  let val = s:parse_dec_val(val)
  let val = s:parse_percent_val(val)
  if val =~ '^[a-fA-F0-9]\{2\}$'
    return val
  else
    return ''
  end
endfunction

" Conver Alpha value to HEX
function! s:parse_alpha_val(val)
  let val = a:val
  let val = substitute(val, '^ \+', '', '')
  let val = substitute(val, ' \+$', '', '')
  let val = s:parse_dec_alpha_val(val)
  let val = s:parse_percent_val(val)
  if val =~ '^[a-fA-F0-9]\{2\}$'
    return val
  else
    return ''
  end
endfunction

" Get cursor color in RGB[A] format
" return [color, start, end]
function! s:parse_rgb_color(colour)
  if a:colour[0] != ''
    return a:colour
  end
  let w = a:colour[0]
  let line = getline('.')
  let col = col('.')
  let start_col = 0
  let pattern = '\crgba\?([0-9 ,\-\.%]\+)'
  while 1
    let start = match(line, pattern, start_col)
    let end = matchend(line, pattern, start_col)
    if start > -1
      if col >= start + 1 && col <= end
        let def = matchstr(line, pattern, start_col)
        let def = substitute(def, '\c^rgba\?(', '', '')
        let def = substitute(def, ')$', '', '')
        let defs = split(def, ',')
        if len(defs) < 3
          return ''
        end
        let cr = s:parse_rgb_val(defs[0])
        let cg = s:parse_rgb_val(defs[1])
        let cb = s:parse_rgb_val(defs[2])
        let alpha = ''
        if len(defs) > 3
          let alpha = s:parse_alpha_val(defs[3])
        endif
        if cr != '' && cg != '' && cb != ''
          if def =~ '%'
            let format = 'RGB100'
          else
            let format = 'RGBCSS'
          endif
          return ['#' . cr . cg . cb . alpha, start, end, format, '']
        else
          return ['', col, col, '', '']
        end
        break
      end
      let start_col = end
    else
      break
    end
  endwhile
  return a:colour
endfunction

function! s:parse_color()
  let colour = ['']
  let colour = s:parse_hex_color(colour)
  let colour = s:parse_rgb_color(colour)
  let w = colour[0]

  if w =~ '#\([a-fA-F0-9]\{3,8\}\)'
    let offset = 2
    let mult = 255
    if len(w) < 7
      let offset = 1
      let mult = mult * 17
    endif
    if len(colour) > 1
      let alpha = ''
      if len(w) == 5
        let alpha = w[4] . w[4]
      endif
      if len(w) == 9
        let alpha = w[7] . w[8]
      endif
      let colour[4] = alpha
    endif
    let cr = str2nr(strpart(w,1,offset), 16) * mult
    let cg = str2nr(strpart(w,1+offset,offset), 16) * mult
    let cb = str2nr(strpart(w,1+2*offset,offset), 16) * mult
    let colour[0] = printf('default color {%d,%d,%d}', cr, cg, cb)
    return colour
  endif

  let colour[0] = printf('default color {%d,%d,%d}', 65535, 65535, 65535)
  return colour
endfunction

function! s:pick_colour(default)
  let lst = remove(s:ascrpt, 4)
  let colour = a:default
  let result = system("osascript " . join(insert(s:ascrpt, colour[0], 4), ' '))
  if result =~ '[0-9]\+,[0-9]\+,[0-9]\+'
    let colour[0] = strpart(result, 0, len(result) - 1)
    return colour
  else
    return ['']
  end
endfunction

function! s:replace_colour(col)
  let colour = a:col[0]
  if colour != '' 
    let start = a:col[1]
    let end = a:col[2]
    let line = getline('.')
    let line = strpart(line, 0, start) . colour . strpart(line, end, len(line) - end)
    call setline(line('.'), line)
  end
endfunction

function! s:colour_rgb(colour)
  return a:colour
endfunction

function! s:colour_hex(colour)
  let colour = a:colour
  if colour[0] == ''
    return colour
  else
    let rgb = split(colour[0], ',')
    if len(colour) > 1 && colour[4] != ''
      let colour[0] = printf('#%02X%02X%02X%02X', str2nr(rgb[0])/255, str2nr(rgb[1])/255, str2nr(rgb[2])/255, str2nr(colour[4], 16))
    else
      let colour[0] = printf('#%02X%02X%02X', str2nr(rgb[0])/255, str2nr(rgb[1])/255, str2nr(rgb[2])/255)
    endif
    return colour
  end
endfunction

function! s:colour_rgbcss(colour)
  let colour = a:colour
  if colour[0] == ''
    return colour
  else
    let rgb = split(colour[0], ',')
    if len(colour) > 1 && colour[4] != ''
      let colour[0] = printf('rgba(%d, %d, %d, %.2f)', str2nr(rgb[0])/255, str2nr(rgb[1])/255, str2nr(rgb[2])/255, str2nr(colour[4], 16)/255.0)
    else
      let colour[0] = printf('rgb(%d, %d, %d)', str2nr(rgb[0])/255, str2nr(rgb[1])/255, str2nr(rgb[2])/255)
    endif
    return colour
  end
endfunction

function! s:colour_rgbcss100(colour)
  let colour = a:colour
  if colour[0] == ''
    return colour
  else
    let rgb = split(colour[0], ',')
    let cr = round(str2nr(rgb[0])*100/65535.0)
    let cg = round(str2nr(rgb[1])*100/65535.0)
    let cb = round(str2nr(rgb[2])*100/65535.0)
    if len(colour) > 1 && colour[4] != ''
      let colour[0] = printf('rgba(%.0f%%, %.0f%%, %.0f%%, %.0f%%)', cr, cg, cb, round(str2nr(colour[4], 16)*100/255.0))
    else
      let colour[0] = printf('rgb(%.0f%%, %.0f%%, %.0f%%)', str2nr(cr, cg, cb)
    endif
    return colour
  end
endfunction

function! s:colour(colour)
  if a:colour[0] == ''
    return a:colour
  elseif len(a:colour) > 3
    let format = a:colour[3]
  else
    let format = 'HEX'
  endif
  if format == 'HEX'
    return s:colour_hex(a:colour)
  elseif format == 'RGBCSS'
    return s:colour_rgbcss(a:colour)
  elseif format == 'RGB100'
    return s:colour_rgbcss100(a:colour)
  endif
  return a:colour
endfunction

command! Color       :call s:replace_colour(s:colour(       s:pick_colour(s:parse_color())))
command! ColorRGB    :call s:replace_colour(s:colour_rgb(   s:pick_colour(s:parse_color())))
command! ColorRGBCSS :call s:replace_colour(s:colour_rgbcss(s:pick_colour(s:parse_color())))
command! ColorRGB100 :call s:replace_colour(s:colour_rgb100(s:pick_colour(s:parse_color())))
command! ColorHEX    :call s:replace_colour(s:colour_hex(   s:pick_colour(s:parse_color())))

