"==============================================================================
" region utils
"==============================================================================
" delete_content : delete content in region
"   if region make from between '<foo>' and '</foo>'
"   --------------------
"   begin:<foo>
"   </foo>:end
"   --------------------
"   this function make the content as following
"   --------------------
"   begin::end
"   --------------------
function! zencoding#util#delete_content(region)
  let lines = getline(a:region[0][0], a:region[1][0])
  call setpos('.', [0, a:region[0][0], a:region[0][1], 0])
  silent! exe "delete ".(a:region[1][0] - a:region[0][0])
  call setline(line('.'), lines[0][:a:region[0][1]-2] . lines[-1][a:region[1][1]])
endfunction

" change_content : change content in region
"   if region make from between '<foo>' and '</foo>'
"   --------------------
"   begin:<foo>
"   </foo>:end
"   --------------------
"   and content is
"   --------------------
"   foo
"   bar
"   baz
"   --------------------
"   this function make the content as following
"   --------------------
"   begin:foo
"   bar
"   baz:end
"   --------------------
function! zencoding#util#change_content(region, content)
  let newlines = split(a:content, '\n', 1)
  let oldlines = getline(a:region[0][0], a:region[1][0])
  call setpos('.', [0, a:region[0][0], a:region[0][1], 0])
  silent! exe "delete ".(a:region[1][0] - a:region[0][0])
  if len(newlines) == 0
    let tmp = ''
    if a:region[0][1] > 1
      let tmp = oldlines[0][:a:region[0][1]-2]
    endif
    if a:region[1][1] >= 1
      let tmp .= oldlines[-1][a:region[1][1]:]
    endif
    call setline(line('.'), tmp)
  elseif len(newlines) == 1
    if a:region[0][1] > 1
      let newlines[0] = oldlines[0][:a:region[0][1]-2] . newlines[0]
    endif
    if a:region[1][1] >= 1
      let newlines[0] .= oldlines[-1][a:region[1][1]:]
    endif
    call setline(line('.'), newlines[0])
  else
    if a:region[0][1] > 1
      let newlines[0] = oldlines[0][:a:region[0][1]-2] . newlines[0]
    endif
    if a:region[1][1] >= 1
      let newlines[-1] .= oldlines[-1][a:region[1][1]:]
    endif
    call setline(line('.'), newlines[0])
    call append(line('.'), newlines[1:])
  endif
endfunction

" select_region : select region
"   this function make a selection of region
function! zencoding#util#select_region(region)
  call setpos('.', [0, a:region[1][0], a:region[1][1], 0])
  normal! v
  call setpos('.', [0, a:region[0][0], a:region[0][1], 0])
endfunction

" point_in_region : check point is in the region
"   this function return 0 or 1
function! zencoding#util#point_in_region(point, region)
  if !zencoding#util#region_is_valid(a:region) | return 0 | endif
  if a:region[0][0] > a:point[0] | return 0 | endif
  if a:region[1][0] < a:point[0] | return 0 | endif
  if a:region[0][0] == a:point[0] && a:region[0][1] > a:point[1] | return 0 | endif
  if a:region[1][0] == a:point[0] && a:region[1][1] < a:point[1] | return 0 | endif
  return 1
endfunction

" cursor_in_region : check cursor is in the region
"   this function return 0 or 1
function! zencoding#util#cursor_in_region(region)
  if !zencoding#util#region_is_valid(a:region) | return 0 | endif
  let cur = getpos('.')[1:2]
  return zencoding#util#point_in_region(cur, a:region)
endfunction

" region_is_valid : check region is valid
"   this function return 0 or 1
function! zencoding#util#region_is_valid(region)
  if a:region[0][0] == 0 || a:region[1][0] == 0 | return 0 | endif
  return 1
endfunction

" search_region : make region from pattern which is composing start/end
"   this function return array of position
function! zencoding#util#search_region(start, end)
  return [searchpairpos(a:start, '', a:end, 'bcnW'), searchpairpos(a:start, '\%#', a:end, 'nW')]
endfunction

" get_content : get content in region
"   this function return string in region
function! zencoding#util#get_content(region)
  if !zencoding#util#region_is_valid(a:region)
    return ''
  endif
  let lines = getline(a:region[0][0], a:region[1][0])
  if a:region[0][0] == a:region[1][0]
    let lines[0] = lines[0][a:region[0][1]-1:a:region[1][1]-1]
  else
    let lines[0] = lines[0][a:region[0][1]-1:]
    let lines[-1] = lines[-1][:a:region[1][1]-1]
  endif
  return join(lines, "\n")
endfunction

" region_in_region : check region is in the region
"   this function return 0 or 1
function! zencoding#util#region_in_region(outer, inner)
  if !zencoding#util#region_is_valid(a:inner) || !zencoding#util#region_is_valid(a:outer)
    return 0
  endif
  return zencoding#util#point_in_region(a:inner[0], a:outer) && zencoding#util#point_in_region(a:inner[1], a:outer)
endfunction

" get_visualblock : get region of visual block
"   this function return region of visual block
function! zencoding#util#get_visualblock()
  return [[line("'<"), col("'<")], [line("'>"), col("'>")]]
endfunction

"==============================================================================
" html utils
"==============================================================================
function! zencoding#util#get_content_from_url(url, utf8)
  silent! new
  if a:utf8
    silent! exec '0r ++enc=utf8 !'.g:zencoding_curl_command.' "'.substitute(a:url, '#.*', '', '').'"'
  else
    silent! exec '0r!'.g:zencoding_curl_command.' "'.substitute(a:url, '#.*', '', '').'"'
  endif
  let ret = join(getline(1, '$'), "\n")
  silent! bw!
  return ret
endfunction

function! zencoding#util#get_text_from_html(buf)
  let threshold_len = 100
  let threshold_per = 0.1
  let buf = a:buf

  let buf = strpart(buf, stridx(buf, '</head>'))
  let buf = substitute(buf, '<style[^>]*>.\{-}</style>', '', 'g')
  let buf = substitute(buf, '<script[^>]*>.\{-}</script>', '', 'g')
  let res = ''
  let max = 0
  let mx = '\(<td[^>]\{-}>\)\|\(<\/td>\)\|\(<div[^>]\{-}>\)\|\(<\/div>\)'
  let m = split(buf, mx)
  for str in m
    let c = split(str, '<[^>]*?>')
    let str = substitute(str, '<[^>]\{-}>', ' ', 'g')
    let str = substitute(str, '&gt;', '>', 'g')
    let str = substitute(str, '&lt;', '<', 'g')
    let str = substitute(str, '&quot;', '"', 'g')
    let str = substitute(str, '&apos;', "'", 'g')
    let str = substitute(str, '&nbsp;', ' ', 'g')
    let str = substitute(str, '&yen;', '\&#65509;', 'g')
    let str = substitute(str, '&amp;', '\&', 'g')
    let str = substitute(str, '^\s*\(.*\)\s*$', '\1', '')
    let str = substitute(str, '\s\+', ' ', 'g')
    let l = len(str)
    if l > threshold_len
      let per = (l+0.0) / len(c)
      if max < l && per > threshold_per
        let max = l
        let res = str
      endif
    endif
  endfor
  let res = substitute(res, '^\s*\(.*\)\s*$', '\1', 'g')
  return res
endfunction
