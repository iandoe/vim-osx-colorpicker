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
  let val = a:val
  let val = substitute(val, '^ \+', '', '')
  let val = substitute(val, ' \+$', '', '')
  if val =~ '^-\?[0-9\.]\+%$'
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
          return ['', col, col, '', '']
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

function! s:parse_deg_val(deg)
  return abs(str2nr(a:deg)) % 360
endfunction

function! s:hue2rgb(hue, p, q)
  if a:hue > 1
    let hue = a:hue - 1
  elseif a:hue < 0
    let hue = a:hue + 1
  else
    let hue = a:hue
  end
  if hue < 1.0/6
    let color = a:p + (a:q - a:p) * 6 * hue
  elseif hue < 1.0/2
    let color = a:q
  elseif hue < 2.0/3
    let color = a:p + (a:q - a:p) * 6 * (2.0/3 - hue)
  else
    let color = a:p
  endif
  " echom printf('%02x', float2nr(round(color * 255)))
  return printf('%02x', float2nr(round(color * 255)))
endfunction

function! s:hsl2rgb(h, s, l)
  let h = a:h / 360.0
  let s = a:s
  let l = a:l
  if a:l < 0.5
    let q = l * (1 + s)
  else
    let q = l + s - (l * s)
  end
  let p = 2 * l - q
  let cr = s:hue2rgb(h + 1.0/3, p, q)
  let cg = s:hue2rgb(h, p, q)
  let cb = s:hue2rgb(h - 1.0/3, p, q)
  return [cr, cg, cb]
endfunction

" Get cursor color in HSL[A] format
" return [color, start, end]
function! s:parse_hsl_color(colour)
  if a:colour[0] != ''
    return a:colour
  end
  let w = a:colour[0]
  let line = getline('.')
  let col = col('.')
  let start_col = 0
  let pattern = '\chsla\?([0-9 ,\-\.%]\+)'
  while 1
    let start = match(line, pattern, start_col)
    let end = matchend(line, pattern, start_col)
    if start > -1
      if col >= start + 1 && col <= end
        let def = matchstr(line, pattern, start_col)
        let def = substitute(def, '\c^hsla\?(', '', '')
        let def = substitute(def, ')$', '', '')
        let defs = split(def, ',')
        if len(defs) < 3
          return ['', col, col, '', '']
        end
        let h = s:parse_deg_val(defs[0])
        let s = str2nr(s:parse_percent_val(defs[1]), '16') / 255.0
        let l = str2nr(s:parse_percent_val(defs[2]), '16') / 255.0
        let rgb = s:hsl2rgb(h, s, l)
        let cr = rgb[0]
        let cg = rgb[1]
        let cb = rgb[2]
        let alpha = ''
        if len(defs) > 3
          let alpha = s:parse_alpha_val(defs[3])
        endif
        if cr != '' && cg != '' && cb != ''
          let format = 'HSL'
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
  let colour = s:parse_hsl_color(colour)
  let w = colour[0]

  if w =~ '#\([a-fA-F0-9]\{3,8\}\)'
    let offset = 2
    if len(w) < 7
      let offset = 1
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
    let cr = strpart(w, 1, offset)
    let cg = strpart(w, 1 + offset, offset)
    let cb = strpart(w, 1 + 2 * offset, offset)
    if len(w) < 7
      let cr = cr . cr
      let cg = cg . cg
      let cb = cb . cb
    endif
    let cr = s:two2four(str2nr(cr, 16))
    let cg = s:two2four(str2nr(cg, 16))
    let cb = s:two2four(str2nr(cb, 16))
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

" 4 byte to 2 byte
function! s:four2two(four)
  return  a:four * 255 / 65535
endfunction

" 2 byte to 4 byte
function! s:two2four(two)
  return a:two * 65535 / 255
endfunction

function! s:colour_hex(colour)
  let colour = a:colour
  if colour[0] == ''
    return colour
  else
    let rgb = split(colour[0], ',')
    let cr = s:four2two(str2nr(rgb[0]))
    let cg = s:four2two(str2nr(rgb[1]))
    let cb = s:four2two(str2nr(rgb[2]))
    if len(colour) > 1 && colour[4] != ''
      let colour[0] = printf('#%02X%02X%02X%02X', cr, cg, cb, str2nr(colour[4], 16))
    else
      let colour[0] = printf('#%02X%02X%02X', cr, cg, cb)
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
    let cr = s:four2two(str2nr(rgb[0]))
    let cg = s:four2two(str2nr(rgb[1]))
    let cb = s:four2two(str2nr(rgb[2]))
    if len(colour) > 1 && colour[4] != ''
      let colour[0] = printf('rgba(%d, %d, %d, %.2f)', cr, cg, cb, str2nr(colour[4], 16)/255.0)
    else
      let colour[0] = printf('rgb(%d, %d, %d)', cr, cg, cb)
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
    let cr = s:four2two(str2nr(rgb[0])) * 100 / 255.0
    let cg = s:four2two(str2nr(rgb[1])) * 100 / 255.0
    let cb = s:four2two(str2nr(rgb[2])) * 100 / 255.0
    if len(colour) > 1 && colour[4] != ''
      let colour[0] = printf('rgba(%.0f%%, %.0f%%, %.0f%%, %.0f%%)', cr, cg, cb, round(str2nr(colour[4], 16)*100/255.0))
    else
      let colour[0] = printf('rgb(%.0f%%, %.0f%%, %.0f%%)', cr, cg, cb)
    endif
    return colour
  end
endfunction

function! s:rgb2hsl(cr, cg, cb)
  let ma = max([a:cr, a:cg, a:cb]) / 255.0
  let mi = min([a:cr, a:cg, a:cb]) / 255.0
  let cr = a:cr / 255.0
  let cg = a:cg / 255.0
  let cb = a:cb / 255.0
  if ma == mi
    let h = 0
  elseif ma == cr && cg >= cb
    let h = 60 * (cg - cb) / (ma - mi)
  elseif ma == cr && cg < cb
    let h = 60 * (cg - cb) / (ma - mi) + 360
  elseif ma == cg
    let h = 60 * (cb - cr) / (ma - mi) + 120
  else "if ma == cb
    let h = 60 * (cb - cr) / (ma - mi) + 240
  endif
  let h = float2nr(h) % 360

  let l = 0.5 * (ma + mi)

  if l == 0 || ma == mi
    let s = 0
  elseif l > 0 && l <= 0.5
    let s = (ma - mi) / (2 * l)
  else " if l > 0.5
    let s = (ma - mi) / (2 * (1 - l))
  endif
  return [h, s, l]
endfunction

function! s:colour_hsl(colour)
  let colour = a:colour
  if colour[0] == ''
    return colour
  else
    let rgb = split(colour[0], ',')
    let cr = s:four2two(str2nr(rgb[0]))
    let cg = s:four2two(str2nr(rgb[1]))
    let cb = s:four2two(str2nr(rgb[2]))
    let hsl = s:rgb2hsl(cr, cg, cb)
    let h = hsl[0]
    let s = hsl[1]
    let l = hsl[2]
    if len(colour) > 1 && colour[4] != ''
      let colour[0] = printf('hsla(%d, %.0f%%, %.0f%%, %.0f%%)', h, s * 100, l * 100, round(str2nr(colour[4], 16)*100/255.0))
    else
      let colour[0] = printf('hsl(%d, %.0f%%, %.0f%%)', h, s * 100, l * 100)
    endif
    return colour
  end
endfunction


function! s:colour(colour)
  if a:colour[0] == ''
    return a:colour
  elseif len(a:colour) > 3
    let format = a:colour[3]
  endif
  if format == ''
    let format = 'HEX'
  endif
  if format == 'HEX'
    return s:colour_hex(a:colour)
  elseif format == 'RGBCSS'
    return s:colour_rgbcss(a:colour)
  elseif format == 'RGB100'
    return s:colour_rgbcss100(a:colour)
  elseif format == 'HSL'
    return s:colour_hsl(a:colour)
  endif
  return a:colour
endfunction

command! Color       :call s:replace_colour(s:colour(          s:pick_colour(s:parse_color())))
command! ColorRGB    :call s:replace_colour(s:colour_rgb(      s:pick_colour(s:parse_color())))
command! ColorRGBCSS :call s:replace_colour(s:colour_rgbcss(   s:pick_colour(s:parse_color())))
command! ColorRGB100 :call s:replace_colour(s:colour_rgbcss100(s:pick_colour(s:parse_color())))
command! ColorHSL    :call s:replace_colour(s:colour_hsl(      s:pick_colour(s:parse_color())))
command! ColorHEX    :call s:replace_colour(s:colour_hex(      s:pick_colour(s:parse_color())))

