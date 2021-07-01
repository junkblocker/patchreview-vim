" VIM plugin for doing single, multi-patch or diff code reviews             {{{
" Home:  http://www.vim.org/scripts/script.php?script_id=1563

" Version       : 2.0.2                                                     {{{
" Author        : Manpreet Singh < junkblocker@yahoo.com >
" Copyright     : 2006-2021 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"
" Changelog : {{{
"
"   2.0.2 - Bugfix in handing added/deleted files
"   2.0.1 - Bugfix in handing added/deleted files
"   2.0.0 - Allow keeping autocmds enabled during processing with the
"           g:patchreview_ignore_events flag
"         - Better strip level guessing
"         - Miscellaneous accumulated fixes
"   1.3.0 - Added g:patchreview_foldlevel setting
"         - Added g:patchreview_disable_syntax control syntax highlighting
"         - Prevent most autocmds from executing during plugin execution
"         - Add dein.vim & consolidate install instructions
"         - Linting, README and help fixes and improvements
"         - Fix and enhance the notification example
"         - Fix DiffReview count style invocation
"         - ignore shell error for bzr diff as it returns 1 on differences
"           (lutostag)
"
"   1.2.1 - Added pathogen instructions (Daniel Lobato García)
"           Fixed subversion support (wilywampa, Michael Leuchtenburg)
"
"   1.2.0 - Support # prefixed comment lines in patches
"           Better FreeBSD detection
"
"   1.1.1 - Better filepath/strip level calculation
"           Some cleanup
"
"   1.1.0 - Added option to open diffs on the right
"         - Added some basic tests (internal)
"
"   1.0.9 - Commented lines left uncommented
"
"   1.0.8 - Fix embarassing breakage
"         - Ensure folds are closed at diff creation
"         - Make string truncation wide character aware for vim older than 7.3
"         - Minor code style change
"         - Show parse result in case of inapplicable patch
"         - Prevent empty blank line 1 in log buffer
"
"   1.0.7 - Added support for fossil
"         - Internal code style changes.
"         - Minor improvement in help friendliness
"
"   1.0.6 - Convert rejects to unified format if possible unless disabled
"
"   1.0.5 - Fixed context format patch handling
"           minor *BSD detection improvement
"
"   1.0.4 - patchreview was broken in vim 7.2
"
"   1.0.3 - Perforce diff was skipping files added via branching
"
"   1.0.2 - Fix for system's patch command on BSDs.
"         - Better exception handling
"
"   1.0.1 - Set foldmethod to diff for patched buffers
"
"   1.0 - Added Perforce support
"       - Add support for arbitrary diff generation commands
"       - Added ability to plug in new version control systems by others
"       - Added ability to create diffs in a way which lets session
"         save/restore work better
"
"   0.4 - Added wiggle support
"       - Added ReversePatchReview command
"       - Added automatic strip count guessing support
"       - Handle paths with special characters in them
"       - Remove patchutils use completely as we can do more with the pure
"         vim version
"       - Show diff if rejections but partially applied
"       - Added patchreview_pre/postfunc for long postreview jobs
"
"   0.3.2 - Some diff extraction fixes and behavior improvement.
"
"   0.3.1 - Do not open the status buffer in all tabs.
"
"   0.3 - Added git diff support
"       - Added some error handling for open files by opening them in read
"         only mode
"
"   0.2.2 - Security fixes by removing custom tempfile creation
"         - Removed need for DiffReviewCleanup/PatchReviewCleanup
"         - Better command execution error detection and display
"         - Improved diff view and folding by ignoring modelines
"         - Improved tab labels display
"
"   0.2.1 - Minor temp directory autodetection logic and cleanup
"
"   0.2 - Removed the need for filterdiff by implementing it in pure vim script
"       - Added DiffReview command for reverse (changed repository to
"         pristine state) reviews.
"         (PatchReview does pristine repository to patch review)
"       - DiffReview does automatic detection and generation of diffs for
"         various Source Control systems
"       - Skip load if VIM 7.0 or higher unavailable
"
"   0.1 - First released
"}}}
"}}}
" Initialization {{{
" Enabled only during development
" unlet! g:loaded_patchreview
" unlet! g:patchreview_patch
" let g:patchreview_patch = 'patch'

" load only once
if &cp || v:version < 700
  finish
endif

let s:msgbufname = '--PatchReview_Messages--'

let s:me = {}

let s:vsplit = get(g:, 'patchreview_split_right', 0)
      \ ? 'vertical rightbelow'
      \ : 'vertical leftabove'

let s:disable_syntax = get(g:, 'patchreview_disable_syntax', 1)

let s:foldlevel = get(g:, 'patchreview_foldlevel', 0)

let s:modules = {}
" }}}
" Functions {{{
let s:_executable = {}
function! s:executable(expr) abort
    let s:_executable[a:expr] = get(s:_executable, a:expr, executable(a:expr))
    return s:_executable[a:expr]
endfunction
" String display width utilities {{{
" The string display width functions were imported from vital.vim
" https://github.com/vim-jp/vital.vim (Public Domain)
if exists('*strdisplaywidth')
  " Use builtin function.
  function! s:me.wcswidth(str) " {{{
    return strdisplaywidth(a:str)
  endfunction
  " }}}
else
  function! s:me.wcswidth(str) " {{{
    if a:str =~# '^[\x00-\x7f]*$'
      return 2 * strlen(a:str)
            \ - strlen(substitute(a:str, '[\x00-\x08\x0b-\x1f\x7f]', '', 'g'))
    end

    let l:mx_first = '^\(.\)'
    let l:str = a:str
    let l:width = 0
    while 1
      let l:ucs = char2nr(substitute(l:str, l:mx_first, '\1', ''))
      if l:ucs == 0
        break
      endif
      let l:width += s:_wcwidth(l:ucs)
      let l:str = substitute(l:str, l:mx_first, '', '')
    endwhile
    return l:width
  endfunction
  " }}}
  function! s:_wcwidth(ucs) " UTF-8 only. {{{
    let l:ucs = a:ucs
    if l:ucs > 0x7f && l:ucs <= 0xff
      return 4
    endif
    if l:ucs <= 0x08 || 0x0b <= l:ucs && l:ucs <= 0x1f || l:ucs == 0x7f
      return 2
    endif
    if (l:ucs >= 0x1100
          \  && (l:ucs <= 0x115f
          \  || l:ucs == 0x2329
          \  || l:ucs == 0x232a
          \  || (l:ucs >= 0x2e80 && l:ucs <= 0xa4cf
          \      && l:ucs != 0x303f)
          \  || (l:ucs >= 0xac00 && l:ucs <= 0xd7a3)
          \  || (l:ucs >= 0xf900 && l:ucs <= 0xfaff)
          \  || (l:ucs >= 0xfe30 && l:ucs <= 0xfe6f)
          \  || (l:ucs >= 0xff00 && l:ucs <= 0xff60)
          \  || (l:ucs >= 0xffe0 && l:ucs <= 0xffe6)
          \  || (l:ucs >= 0x20000 && l:ucs <= 0x2fffd)
          \  || (l:ucs >= 0x30000 && l:ucs <= 0x3fffd)
          \  ))
      return 2
    endif
    return 1
  endfunction
  " }}}
endif
function! s:me.strwidthpart(str, width) " {{{
  if a:width <= 0
    return ''
  endif
  let l:ret = a:str
  let l:width = s:me.wcswidth(a:str)
  while l:width > a:width
    let char = matchstr(l:ret, '.$')
    let l:ret = l:ret[: -1 - len(char)]
    let l:width -= s:me.wcswidth(char)
  endwhile

  return l:ret
endfunction
" }}}
function! s:me.truncate(str, width) " {{{
  if a:str =~# '^[\x20-\x7e]*$'
    return len(a:str) < a:width ?
          \ printf('%-'.a:width.'s', a:str) : strpart(a:str, 0, a:width)
  endif

  let l:ret = a:str
  let l:width = s:me.wcswidth(a:str)
  if l:width > a:width
    let l:ret = s:me.strwidthpart(l:ret, a:width)
    let l:width = s:me.wcswidth(l:ret)
  endif

  if l:width < a:width
    let l:ret .= repeat(' ', a:width - l:width)
  endif

  return l:ret
endfunction
" }}}
" }}}
function! s:me.progress(str)                                                 "{{{
  call s:me.debug(a:str)
  if ! &cmdheight
    return
  endif
  redraw
  echo s:me.truncate(a:str, &columns * min([&cmdheight, 1]) - 1)
endfunction
" }}}
function! s:me.debug(str)                                                  "{{{
  if exists('g:patchreview_debug') && g:patchreview_debug
    call s:me.buflog('DEBUG: ' . a:str)
  endif
endfunction
"}}}
function! s:wipe_message_buffer()                                            "{{{
  let l:cur_tabnr = tabpagenr()
  let l:cur_winnr = winnr()
  if exists('s:origtabpagenr')
    exe 'tabnext ' . s:origtabpagenr
  endif
  let l:winnum = bufwinnr(s:msgbufname)
  if l:winnum != -1 " If the window is already open, jump to it
    if winnr() != l:winnum
      exe l:winnum . 'wincmd w'
      bw
    endif
  endif
  exe 'tabnext ' . l:cur_tabnr
  if winnr() != l:cur_winnr
    exe l:cur_winnr . 'wincmd w'
  endif
endfunction
"}}}
function! s:me.buflog(...)                                                   "{{{
  " Usage: s:me.buflog(msg, [go_back])
  "            default go_back = 1
  "
  let l:cur_tabnr = tabpagenr()
  let l:cur_winnr = winnr()
  if exists('s:msgbuftabnr')
    exe 'tabnext ' . s:msgbuftabnr
  else
    let s:msgbuftabnr = tabpagenr()
  endif
  let l:msgtab_orgwinnr = winnr()
  if ! exists('s:msgbufname')
    let s:msgbufname = '--PatchReview_Messages--'
  endif
  let l:winnum = bufwinnr(s:msgbufname)
  if l:winnum != -1 " If the window is already open, jump to it
    if winnr() != l:winnum
      exe l:winnum . 'wincmd w'
    endif
  else
    let l:bufnum = bufnr(s:msgbufname)
    let l:wcmd = l:bufnum == -1 ? s:msgbufname : '+buffer' . l:bufnum
    exe 'silent! botright 5split ' . l:wcmd
    let s:msgbuftabnr = tabpagenr()
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    let b:just_created = 1
  endif
  setlocal modifiable
  if a:0 != 0
    silent! $put =a:1
    if get(b:, 'just_created', 0)
      normal! gg
      0 delete _
      let b:just_created = 0
    endif
  endif
  normal! G
  setlocal nomodifiable
  setlocal winheight=5

  exe l:msgtab_orgwinnr . 'wincmd w'
  if a:0 == 1 ||  a:0 > 1 && a:2 != 0
    exe 'tabnext ' . l:cur_tabnr
    if l:cur_winnr != -1 && winnr() != l:cur_winnr
      exe l:cur_winnr . 'wincmd w'
    endif
  endif
endfunction
"}}}
function! s:check_binary(binary_name)                                 "{{{
  " Verify that binary_name is specified or available
  if ! exists('g:patchreview_' . a:binary_name)
    if s:executable(a:binary_name)
      let g:patchreview_{a:binary_name} = a:binary_name
      return 1
    else
      call s:me.buflog('g:patchreview_' . a:binary_name . ' is not defined and ' . a:binary_name . ' command could not be found on path.')
      call s:me.buflog('Please define it in your .vimrc.')
      return 0
    endif
  elseif ! s:executable(g:patchreview_{a:binary_name})
    call s:me.buflog('Specified g:patchreview_' . a:binary_name . ' [' . g:patchreview_{a:binary_name} . '] is not executable.')
    return 0
  else
    return 1
  endif
endfunction
"}}}
function! s:guess_prefix_strip_value(diff_file_path, default_strip) " {{{
  call s:me.debug("Trying to guess strip level for " . a:diff_file_path . " with " .a:default_strip . " as default")
  if stridx(a:diff_file_path, '/') != -1
    let l:splitchar = '/'
  elseif stridx(a:diff_file_path, '\') !=  -1
    let l:splitchar = '\'
  else
    let l:splitchar = '/'
  endif
  let l:path = split(a:diff_file_path, l:splitchar)
  let i = 0
  while i <= 15
    if len(l:path) >= i
      if filereadable(join(['.'] + l:path[i : ], l:splitchar))
        let s:guess_strip[i] += 1
        call s:me.debug("Guessing strip: " . i)
        return
      endif
    endif
    let i = i + 1
  endwhile
  let l:path = split(a:diff_file_path, l:splitchar)[:-2]
  let i = 0
  while i <= 15
    let j = len(l:path) - i
    while j > 0
      let l:checkdir = join(['.'] + l:path[i:j], l:splitchar)
      if l:checkdir == '.'
        break
      endif
      if isdirectory(l:checkdir)
        let s:guess_strip[i] += 1
        call s:me.debug("Guessing strip via directory check : " . i)
        return
      endif
      let j = j - 1
    endwhile
    let i = i + 1
  endwhile
  call s:me.debug("REALLY Guessing strip: " . a:default_strip)
  let s:guess_strip[a:default_strip] += 1
endfunction
" }}}
function! s:is_bsd() " {{{
  return filereadable('/etc/rc.subr')
endfunction
" }}}
function! s:state(...)  " For easy manipulation of diff parsing state {{{
  if a:0 != 0
    if ! exists('s:PARSE_STATE') || s:PARSE_STATE != a:1
      call s:me.debug('Set PARSE_STATE: ' . a:1)
    endif
    let s:PARSE_STATE = a:1
  else
    if ! exists('s:PARSE_STATE')
      let s:PARSE_STATE = 'START'
    endif
    return s:PARSE_STATE
  endif
endfunction
"}}}
function! s:temp_name()                                                  "{{{
  " Create diffs in a way which lets session save/restore work better
  if ! exists('g:patchreview_persist')
    return tempname()
  endif
  if ! exists('g:patchreview_persist_dir')
      let g:patchreview_persist_dir = expand("~/.patchreview/" . strftime("%y%m%d%H%M%S"))
      if ! isdirectory(g:patchreview_persist_dir)
        call mkdir(g:patchreview_persist_dir, "p", 0777)
      endif
  endif
  if ! exists('s:last_tempname')
    let s:last_tempname = 0
  endif
  let s:last_tempname += 1
  let l:temp_file_name = g:patchreview_persist_dir . '/' . s:last_tempname
  while filereadable(l:temp_file_name)
    let s:last_tempname += 1
    let l:temp_file_name = g:patchreview_persist_dir . '/' . s:last_tempname
  endwhile
  return l:temp_file_name
endfunction
" }}}
function! patchreview#get_patchfile_lines(patchfile)                      " {{{
  "
  " Throws: "File " . a:patchfile . " is not readable"
  "
  let l:patchfile = expand(a:patchfile, ":p")
  if ! filereadable(expand(l:patchfile))
    throw "File " . l:patchfile . " is not readable"
  endif
  return readfile(l:patchfile, 'b')
endfunction
" }}}
function! s:me.generate_diff(shell_escaped_cmd)                            "{{{
  let l:diff = []
  let v:errmsg = ''
  let l:cout = system(a:shell_escaped_cmd)
  if v:errmsg != '' || v:shell_error && split(a:shell_escaped_cmd)[0] != 'bzr'
    call s:me.buflog(v:errmsg)
    call s:me.buflog('Could not execute [' . a:shell_escaped_cmd . ']')
    if v:shell_error
      call s:me.buflog('Error code: ' . v:shell_error)
    endif
    call s:me.buflog(l:cout)
  else
    let l:diff = split(l:cout, '[\n\r]')
  endif
  return l:diff
endfunction
" }}}
function! patchreview#extract_diffs(lines, default_strip_count)            "{{{
  call s:me.debug("patchreview#extract_diffs called with default_strip_count " . a:default_strip_count)
  " Sets g:patches = {'fail':'', 'patch':[
  " {
  "  'filename': filepath
  "  'type'    : '+' | '-' | '!'
  "  'content' : patch text for this file
  " },
  " ...
  " ]}
  let s:guess_strip = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let g:patches = {'fail' : '', 'patch' : []}
  " SVN Diff
  " Index: file/path
  " ===================================================================
  " --- file/path (revision 490)
  " +++ file/path (working copy)
  " @@ -24,7 +24,8 @@
  "    alias -s tar.gz="echo "
  "
  " Perforce Diff
  " ==== //prod/main/some/f/path#10 - /Users/junkblocker/ws/some/f/path ====
  " @@ -18,10 +18,13 @@
  "
  "
  let l:collect = []
  let l:line_num = 0
  let l:p_first_file = ''
  let l:o_count = -1
  let l:n_count = -1
  let l:c_count = -1
  let l:goal_count = -1
  let l:old_goal_count = -1
  let l:new_goal_count = -1
  let l:p_type = ''
  let l:filepath = ''
  let l:linescount = len(a:lines)
  call s:state('START')
  while l:line_num < l:linescount
    let l:line = a:lines[l:line_num]
    call s:me.debug('|' . l:line . '|')
    let l:line_num += 1
    if l:line =~ '^#'
      continue
    endif
    if s:state() == 'START' " {{{
      let l:mat = matchlist(l:line, '^--- \([^\t]\+\).*$')
      if ! empty(l:mat) && l:mat[1] != ''
        call s:state('MAYBE_UNIFIED_DIFF')
        let l:p_first_file = l:mat[1]
        let l:collect = [l:line]
        continue
      endif
      let l:mat = matchlist(l:line, '^\*\*\* \([^\t]\+\).*$')
      if ! empty(l:mat) && l:mat[1] != ''
        call s:state('MAYBE_CONTEXT_DIFF')
        let l:p_first_file = l:mat[1]
        let l:collect = [l:line]
        continue
      endif
      let l:mat = matchlist(l:line, '^\(Binary files\|Files\) \(.\+\) and \(.+\) differ$')
      if ! empty(l:mat) && l:mat[2] != '' && l:mat[3] != ''
        call s:me.buflog('Ignoring ' . tolower(l:mat[1]) . ' ' . l:mat[2] . ' and ' . l:mat[3])
        continue
      endif
      " Note - Older Perforce (around 2006) generates incorrect diffs
      let l:thisp = escape(expand(getcwd(), ':p'), '\') . '/'
      let l:mat = matchlist(l:line, '^====.*\#\(\d\+\).*' . l:thisp . '\(.*\)\s====\( content\)\?\r\?$')
      if ! empty(l:mat) && l:mat[2] != ''
        let l:p_type = '!'
        let l:filepath = l:mat[2]
        call s:me.progress('Collecting ' . l:filepath)
        let l:collect = ['--- ' . l:filepath . ' (revision ' . l:mat[1] . ')', '+++ ' .  l:filepath . ' (working copy)']
        call s:state('EXPECT_UNIFIED_RANGE_CHUNK')
        continue
      endif
      continue
      " }}}
    elseif s:state() == 'MAYBE_CONTEXT_DIFF' " {{{
      let l:mat = matchlist(l:line, '^--- \([^\t]\+\).*$')
      if empty(l:mat) || l:mat[1] == ''
        call s:state('START')
        let l:line_num -= 1
        continue
      endif
      let l:p_second_file = l:mat[1]
      if l:p_first_file == '/dev/null'
        if l:p_second_file == '/dev/null'
          let g:patches['fail'] = "Malformed diff found at line " . l:line_num
          return
        endif
        let l:p_type = '+'
        let l:filepath = l:p_second_file
      else
        if l:p_second_file == '/dev/null'
          let l:p_type = '-'
          let l:filepath = l:p_first_file
        else
          let l:p_type = '!'
          let l:filepath = l:p_second_file
        endif
      endif
      call s:me.debug('l:p_type ' . l:p_type)
      call s:me.progress('Collecting ' . l:filepath)
      call s:state('EXPECT_15_STARS')
      let l:collect += [l:line]
      " }}}
    elseif s:state() == 'EXPECT_15_STARS' " {{{
      if l:line !~ '^*\{15}$'
        call s:state('START')
        let l:line_num -= 1
        continue
      endif
      call s:state('EXPECT_CONTEXT_CHUNK_HEADER_1')
      let l:collect += [l:line]
      " }}}
    elseif s:state() == 'EXPECT_CONTEXT_CHUNK_HEADER_1' " {{{
      let l:mat = matchlist(l:line, '^\*\*\* \(\d\+,\)\?\(\d\+\) \*\*\*\*$')
      if empty(l:mat) || l:mat[1] == ''
        call s:state('START')
        let l:line_num -= 1
        continue
      endif
      let l:collect += [l:line]
      call s:state('READ_TILL_CONTEXT_FRAGMENT_2')
      continue
      " }}}
    elseif s:state() == 'READ_TILL_CONTEXT_FRAGMENT_2' " {{{
      if l:line !~ '^[ !+-] .*$'
        let l:mat = matchlist(l:line, '^--- \(\d\+\),\(\d\+\) ----$')
        if ! empty(l:mat) && l:mat[1] != '' && l:mat[2] != ''
          let l:goal_count = l:mat[2] - l:mat[1] + 1
          let l:c_count = 0
          call s:state('READ_CONTEXT_CHUNK')
          let l:collect += [l:line]
          continue
        endif
        call s:state('START')
        let l:line_num -= 1
        continue
      endif
      let l:collect += [l:line]
      continue
      " }}}
    elseif s:state() == 'READ_CONTEXT_CHUNK' " {{{
      let l:c_count += 1
      if l:c_count == l:goal_count
        let l:collect += [l:line]
        call s:state('BACKSLASH_OR_CRANGE_EOF')
        continue
      else " goal not met yet
        let l:mat = matchlist(l:line, '^\([\\!+ -]\) .*$')
        if empty(l:mat) || l:mat[1] == ''
          if l:line =~ '^\*\{15}$'
            let l:collect += [l:line]
            call s:state('EXPECT_CONTEXT_CHUNK_HEADER_1')
            continue
          else
            let l:line_num -= 1
            call s:state('START')
            continue
          endif
        endif
        let l:collect += [l:line]
        continue
      endif
      " }}}
    elseif s:state() == 'BACKSLASH_OR_CRANGE_EOF' " {{{
      if l:line =~ '^\\ No newline.*$'   " XXX: Can we go to another chunk from here??
        let l:collect += [l:line]
        let l:this_patch = {}
        let l:this_patch['filename'] = l:filepath
        let l:this_patch['type'] = l:p_type
        let l:this_patch['content'] = l:collect
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        call s:me.progress('Collected  ' . l:filepath)
        if l:p_type == '!'
          call s:guess_prefix_strip_value(l:filepath, a:default_strip_count)
        endif
        call s:state('START')
        continue
      endif
      if l:line =~ '^\*\{15}$'
        let l:collect += [l:line]
        call s:state('EXPECT_CONTEXT_CHUNK_HEADER_1')
        continue
      endif
      let l:this_patch = {'filename': l:filepath, 'type':  l:p_type, 'content':  l:collect}
      let g:patches['patch'] += [l:this_patch]
      unlet! l:this_patch
      let l:line_num -= 1
      call s:me.progress('Collected  ' . l:filepath)
      if l:p_type == '!'
        call s:guess_prefix_strip_value(l:filepath, a:default_strip_count)
      endif
      call s:state('START')
      continue
      " }}}
    elseif s:state() == 'MAYBE_UNIFIED_DIFF' " {{{
      let l:mat = matchlist(l:line, '^+++ \([^\t]\+\).*$')
      if empty(l:mat) || l:mat[1] == ''
        call s:state('START')
        let l:line_num -= 1
        continue
      endif
      let l:p_second_file = l:mat[1]
      if l:p_first_file == '/dev/null'
        if l:p_second_file == '/dev/null'
          let g:patches['fail'] = "Malformed diff found at line " . l:line_num
          return
        endif
        let l:p_type = '+'
        let l:filepath = l:p_second_file
      else
        if l:p_second_file == '/dev/null'
          let l:p_type = '-'
          let l:filepath = l:p_first_file
        else
          let l:p_type = '!'
          if l:p_first_file =~ '^//.*'   " Perforce
            let l:filepath = l:p_second_file
          else
            let l:filepath = l:p_first_file
          endif
        endif
      endif
      call s:me.progress('Collecting ' . l:filepath)
      call s:state('EXPECT_UNIFIED_RANGE_CHUNK')
      let l:collect += [l:line]
      continue
      " }}}
    elseif s:state() == 'EXPECT_UNIFIED_RANGE_CHUNK' "{{{
      let l:mat = matchlist(l:line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
      if ! empty(l:mat)
        let l:old_goal_count = l:mat[2]
        let l:new_goal_count = l:mat[4]
        let l:o_count = 0
        let l:n_count = 0
        call s:state('READ_UNIFIED_CHUNK')
        let l:collect += [l:line]
      else
        let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        call s:me.progress('Collected  ' . l:filepath)
        if l:p_type == '!'
          call s:guess_prefix_strip_value(l:filepath, a:default_strip_count)
        endif
        call s:state('START')
        let l:line_num -= 1
      endif
      continue
      "}}}
    elseif s:state() == 'READ_UNIFIED_CHUNK' " {{{
      if l:o_count == l:old_goal_count && l:n_count == l:new_goal_count
        if l:line =~ '^\\.*$'   " XXX: Can we go to another chunk from here??
          let l:collect += [l:line]
          let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
          let g:patches['patch'] += [l:this_patch]
          unlet! l:this_patch
          call s:me.progress('Collected  ' . l:filepath)
          if l:p_type == '!'
            call s:guess_prefix_strip_value(l:filepath, a:default_strip_count)
          endif
          call s:state('START')
          continue
        endif
        let l:mat = matchlist(l:line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
        if ! empty(l:mat)
          let l:old_goal_count = l:mat[2]
          let l:new_goal_count = l:mat[4]
          let l:o_count = 0
          let l:n_count = 0
          let l:collect += [l:line]
          call s:me.debug("Will collect another unified chunk")
          continue
        endif
        let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        call s:me.progress('Collected  ' . l:filepath)
        if l:p_type == '!'
          call s:guess_prefix_strip_value(l:filepath, a:default_strip_count)
        endif
        let l:line_num -= 1
        call s:state('START')
        continue
      else " goal not met yet
        let l:mat = matchlist(l:line, '^\([\\+ -]\).*$')
        if empty(l:mat) || l:mat[1] == ''
          let l:line_num -= 1
          call s:state('START')
          continue
        endif
        let chr = l:mat[1]
        if chr == '+'
          let l:n_count += 1
        elseif chr == ' '
          let l:o_count += 1
          let l:n_count += 1
        elseif chr == '-'
          let l:o_count += 1
        endif
        let l:collect += [l:line]
        continue
      endif
      " }}}
    else " {{{
      let g:patches['fail'] = "Internal error: Do not use the plugin anymore and if possible please send the diff or patch file you tried it with to Manpreet Singh <junkblocker@yahoo.com>"
      return
    endif " }}}
  endwhile
  "call s:me.buflog(s:state())
  if (
        \ (s:state() == 'READ_CONTEXT_CHUNK'
        \  && l:c_count == l:goal_count
        \ ) ||
        \ (s:state() == 'READ_UNIFIED_CHUNK'
        \  && l:n_count == l:new_goal_count
        \  && l:o_count == l:old_goal_count
        \ )
        \)
    let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
    let g:patches['patch'] += [l:this_patch]
    unlet! l:this_patch
    unlet! lines
    call s:me.progress('Collected  ' . l:filepath)
    if l:p_type == '!' || (l:p_type == '+' && s:reviewmode == 'diff')
      call s:guess_prefix_strip_value(l:filepath, a:default_strip_count)
    endif
  endif
  return
endfunction
"}}}
function! patchreview#patchreview(...)                                     "{{{
  let l:callback_args = ['Patch Review'] + deepcopy(a:000)
  if exists('g:patchreview_prefunc')
    call call(g:patchreview_prefunc, l:callback_args)
  endif
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o' | augroup! patchreview_plugin
  augroup end
  let s:save_shortmess = &shortmess
  let s:save_aw = &autowrite
  let s:save_awa = &autowriteall
  let s:origtabpagenr = tabpagenr()
  let s:equalalways = &equalalways
  let s:eadirection = &eadirection
  set equalalways
  set eadirection=hor
  set shortmess=aW
  call s:wipe_message_buffer()
  let s:reviewmode = 'patch'
  try
    let l:lines = patchreview#get_patchfile_lines(a:1)
    call s:generic_review([l:lines] + a:000[1:])
  catch /.*/
    call s:me.buflog('ERROR: ' . v:exception)
  endtry
  let &eadirection = s:eadirection
  let &equalalways = s:equalalways
  let &autowriteall = s:save_awa
  let &autowrite = s:save_aw
  let &shortmess = s:save_shortmess
  if exists('g:patchreview_postfunc')
    call call(g:patchreview_postfunc, l:callback_args)
  endif
endfunction
"}}}
function! patchreview#reverse_patchreview(...)  "{{{
  let l:callback_args = ['Reverse Patch Review'] + deepcopy(a:000)
  if exists('g:patchreview_prefunc')
    call call(g:patchreview_prefunc, l:callback_args)
  endif
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o' | augroup! patchreview_plugin
  augroup end
  let s:save_shortmess = &shortmess
  let s:save_aw = &autowrite
  let s:save_awa = &autowriteall
  let s:origtabpagenr = tabpagenr()
  let s:equalalways = &equalalways
  let s:eadirection = &eadirection
  set equalalways
  set eadirection=hor
  set shortmess=aW
  call s:wipe_message_buffer()
  let s:reviewmode = 'rpatch'
  try
    let l:lines = patchreview#get_patchfile_lines(a:1)
    call s:generic_review([l:lines] + a:000[1:])
  catch /.*/
    call s:me.buflog('ERROR: ' . v:exception)
  endtry
  let &eadirection = s:eadirection
  let &equalalways = s:equalalways
  let &autowriteall = s:save_awa
  let &autowrite = s:save_aw
  let &shortmess = s:save_shortmess
  if exists('g:patchreview_postfunc')
    call call(g:patchreview_postfunc, l:callback_args)
  endif
endfunction
"}}}
function! s:wiggle(out, rej) " {{{
  if ! s:executable('wiggle')
    return
  endif
  let l:wiggle_out = s:temp_name()
  let v:errmsg = ''
  call system('wiggle --merge ' . shellescape(a:out) . ' ' . shellescape(a:rej) . ' > ' . shellescape(l:wiggle_out))
  if v:errmsg != '' || v:shell_error
    call s:me.buflog('ERROR: wiggle was not completely successful.')
    if v:errmsg != ''
      call s:me.buflog('ERROR: ' . v:errmsg)
    endif
  endif
  if filereadable(l:wiggle_out)
    " modelines in loaded files mess with diff comparison
    let s:keep_modeline=&modeline
    let &modeline=0
    if s:disable_syntax
      syn off
    else
      syn enable
    endif
    silent! exe s:vsplit . ' diffsplit ' . fnameescape(l:wiggle_out)
    setlocal noswapfile
    if s:disable_syntax
      syn off
    else
      syn enable
    endif
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal modifiable
    setlocal nowrap
    " Remove buffer name
    if ! exists('g:patchreview_persist')
      setlocal buftype=nofile
      silent! 0f
    endif
    let &modeline=s:keep_modeline
    if has('folding')
      let &foldlevel=s:foldlevel
    endif
    wincmd p
  endif
endfunction
" }}}
function! s:generic_review(argslist)                                   "{{{
  " diff mode:
  "   arg1 = patchlines
  "   arg2 = strip count
  " patch mode:
  "   arg1 = patchlines
  "   arg2 = directory
  "   arg3 = strip count

  " VIM 7+ required
  if v:version < 700
    call s:me.buflog('This plugin needs VIM 7 or higher')
    return
  endif

  " +diff required
  if ! has('diff')
    call s:me.buflog('This plugin needs VIM built with +diff feature.')
    return
  endif

  let l:filterdiff_warned = 0

  call s:me.debug("Reviewmode: " . s:reviewmode)
  if s:reviewmode == 'diff' || s:reviewmode == 'rpatch'
    let patch_R_options = ['-t', '-R']
  elseif s:reviewmode == 'patch'
    let patch_R_options = []
  else
    call s:me.buflog('Fatal internal error in patchreview.vim plugin')
    return
  endif

  " ----------------------------- patch ------------------------------------
  if s:reviewmode =~ 'patch'
    let l:argc = len(a:argslist)
    if l:argc == 0 || l:argc > 3
      if s:reviewmode == 'patch'
        call s:me.buflog('PatchReview command needs 1 to 3 arguments.')
        return
      endif
      if s:reviewmode == 'rpatch'
        call s:me.buflog('ReversePatchReview command needs 1 to 3 arguments.')
        return
      endif
    endif
    " ARG[0]: patchlines
    let l:patchlines = a:argslist[0]
    " ARG[1]: directory [optional]
    if len(a:argslist) >= 2
      let s:src_dir = expand(a:argslist[1], ':p')
      if ! isdirectory(s:src_dir)
        call s:me.buflog('[' . s:src_dir . '] is not a directory')
        return
      endif
      try
        exe 'cd ' . fnameescape(s:src_dir)
      catch /^.*E344.*/
        call s:me.buflog('Could not change to directory [' . s:src_dir . ']')
        return
      endtry
    endif
    " ARG[2]: strip count [optional]
    if len(a:argslist) == 3
      let l:strip_count = eval(a:argslist[2])
    endif
  " ----------------------------- diff -------------------------------------
  elseif s:reviewmode == 'diff'
    if len(a:argslist) > 2
      call s:me.buflog('Fatal internal error in patchreview.vim plugin')
      return
    endif
    let l:patchlines = a:argslist[0]
    " passed in by default
    let l:strip_count = eval(a:argslist[1])
  else
    call s:me.buflog('Fatal internal error in patchreview.vim plugin')
    return
  endif " diff

  " Verify that patch command and temporary directory are available or specified
  if ! s:check_binary('patch')
    return
  endif

  call s:me.buflog('Source directory: ' . getcwd())
  call s:me.buflog('------------------')
  if exists('l:strip_count')
    let l:defsc = l:strip_count
  elseif s:reviewmode =~ 'patch'
    let l:defsc = 0
  else
    call s:me.buflog('Fatal internal error in patchreview.vim plugin')
    return
  endif
  try
    call patchreview#extract_diffs(l:patchlines, l:defsc)
  catch
    call s:me.buflog('Exception ' . v:exception)
    call s:me.buflog('From ' . v:throwpoint)
    return
  endtry
  let l:cand = 0
  let l:inspecting = 1
  while l:cand < l:inspecting && l:inspecting <= 15
    if s:guess_strip[l:cand] >= s:guess_strip[l:inspecting]
      let l:inspecting += 1
    else
      let l:cand = l:inspecting
    endif
  endwhile
  let l:strip_count = l:cand

  let l:this_patch_num = 0
  let l:total_patches = len(g:patches['patch'])
  for patch in g:patches['patch']
    let l:this_patch_num += 1
    call s:me.progress('Processing ' . l:this_patch_num . '/' . l:total_patches . ' ' . patch.filename)
    call s:me.buflog("Review mode: : " . s:reviewmode . " Patch type: " . patch.type)
    if patch.type !~ '^[!+-]$'
      call s:me.buflog('*** Skipping review generation due to unknown change [' . patch.type . ']')
      unlet! patch
      continue
    endif
    unlet! l:relpath
    let l:relpath = patch.filename
    " XXX: svn diff and hg diff produce different kind of outputs, one requires
    " XXX: stripping but the other doesn't. We need to take care of that
    let l:stripmore = l:strip_count
    let l:stripped_rel_path = l:relpath
    while l:stripmore > 0
      " strip one
      let l:stripped_rel_path = substitute(l:stripped_rel_path, '^[^\\\/]\+[^\\\/]*[\\\/]' , '' , '')
      let l:stripmore -= 1
    endwhile
    if patch.type == '!'
      if s:reviewmode =~ 'patch'
        let l:msgtype = 'Patch modifies file: '
      elseif s:reviewmode == 'diff'
        let l:msgtype = 'File has changes: '
      endif
    elseif patch.type == '+'
      if s:reviewmode =~ 'patch'
        let l:msgtype = 'Patch adds file    : '
      elseif s:reviewmode == 'diff'
        let l:msgtype = 'New file        : '
      endif
    elseif patch.type == '-'
      if s:reviewmode =~ 'patch'
        let l:msgtype = 'Patch removes file : '
      elseif s:reviewmode == 'diff'
        let l:msgtype = 'Removed file    : '
      endif
    else
      call s:me.buflog('Fatal internal error in patchreview.vim plugin')
      return
    endif
    call s:me.buflog(l:msgtype . ' ' . l:relpath)
    let l:bufnum = bufnr(l:relpath)
    if buflisted(l:bufnum) && getbufvar(l:bufnum, '&mod')
      call s:me.buflog('Old buffer for file [' . l:relpath . '] exists in modified state. Skipping review.')
      unlet! patch
      continue
    endif
    let l:tmp_patch = s:temp_name()
    let l:tmp_patched = s:temp_name()
    let l:tmp_patched_rej = l:tmp_patched . '.rej'  " Rejection file created by patch

    try
      " write patch for patch.filename into l:tmp_patch
      " some ports of GNU patch (e.g. UnxUtils) always want DOS end of line in
      " patches while correctly handling any EOLs in files
      if exists("g:patchreview_patch_needs_crlf") && g:patchreview_patch_needs_crlf
        call map(patch.content, 'v:val . "\r"')
      endif
      if writefile(patch.content, l:tmp_patch) != 0
        call s:me.buflog('*** ERROR: Could not save patch to a temporary file.')
        continue
      endif
      "if exists('g:patchreview_debug')
      "  exe 'tabedit ' . l:tmp_patch
      "endif
      if patch.type == '+' && s:reviewmode =~ 'patch'
        let l:inputfile = ''
        if s:is_bsd()
          " BSD patch is not GNU patch but works just fine without the
          " unavailable --binary option
          let l:patchcmd = g:patchreview_patch . ' '
                \ . join(map(['-s', '-o', l:tmp_patched]
                \ + patch_R_options + [l:inputfile],
                \ "shellescape(v:val)"), ' ') . ' < '
                \ . shellescape(l:tmp_patch)
        else
          if patch.type == '+'
            let l:patchcmd = g:patchreview_patch . ' '
                  \ . join(map(['--binary', '-s', '-o', l:tmp_patched]
                  \ + patch_R_options, "shellescape(v:val)"), ' ') . ' < '
                  \ . shellescape(l:tmp_patch)
          else
            let l:patchcmd = g:patchreview_patch . ' '
                  \ . join(map(['--binary', '-s', '-o', l:tmp_patched]
                  \ + patch_R_options + [l:inputfile],
                  \ "shellescape(v:val)"), ' ') . ' < '
                  \ . shellescape(l:tmp_patch)
          endif
        endif
      elseif patch.type == '+' && s:reviewmode == 'diff'
        let l:inputfile = ''
        unlet! l:patchcmd
      else
        let l:inputfile = expand(l:stripped_rel_path, ':p')
        if s:is_bsd()
          " BSD patch is not GNU patch but works just fine without the
          " unavailable --binary option
          let l:patchcmd = g:patchreview_patch . ' '
                \ . join(map(['-s', '-o', l:tmp_patched]
                \ + patch_R_options + [l:inputfile],
                \ "shellescape(v:val)"), ' ') . ' < '
                \ . shellescape(l:tmp_patch)
        else
          let l:patchcmd = g:patchreview_patch . ' '
                \ . join(map(['--binary', '-s', '-o', l:tmp_patched]
                \ + patch_R_options + [l:inputfile],
                \ "shellescape(v:val)"), ' ') . ' < '
                \ . shellescape(l:tmp_patch)
        endif
      endif
      let error = 0
      let l:pout = ''
      if exists('l:patchcmd')
        let v:errmsg = ''
        let l:pout = system(l:patchcmd)
        if v:errmsg != '' || v:shell_error
          let l:errmsg = v:errmsg
          let error = 1
          call s:me.buflog('ERROR: Could not execute patch command.')
          call s:me.buflog('ERROR:     ' . l:patchcmd)
          if l:pout != ''
            call s:me.buflog('ERROR: ' . l:pout)
          endif
          call s:me.buflog('ERROR: ' . l:errmsg)
          if filereadable(l:tmp_patched)
            call s:me.buflog('ERROR: Diff partially shown.')
          else
            call s:me.buflog('ERROR: Diff skipped.')
          endif
        endif
      endif
      silent! exe 'tabedit ' . fnameescape(l:stripped_rel_path)
      if filereadable(l:tmp_patched) && l:pout =~ 'Only garbage was found in the patch input'
        topleft new
        exe 'r ' . fnameescape(l:tmp_patch)
        normal! gg
        0 delete _
        exe 'file bad_patch_for_' . fnameescape(fnamemodify(l:inputfile, ':t'))
        setlocal nomodifiable nomodified ft=diff bufhidden=delete
              \ buftype=nofile noswapfile nowrap nobuflisted
        wincmd p
      endif
      if ! error || filereadable(l:tmp_patched)
        let l:filetype = &filetype
        if exists('l:patchcmd')
          " modelines in loaded files mess with diff comparison
          let s:keep_modeline=&modeline
          let &modeline=0
          if s:disable_syntax
            syn off
          else
            syn enable
          endif
          if patch.type == '+' && s:reviewmode == 'diff'
              silent! exe s:vsplit . ' diffsplit /dev/null'
          else
            silent! exe s:vsplit . ' diffsplit ' . fnameescape(l:tmp_patched)
          endif
          setlocal noswapfile
          if s:disable_syntax
            syn off
          else
            syn enable
          endif
          setlocal bufhidden=delete
          setlocal nobuflisted
          setlocal modifiable
          setlocal nowrap
          " Remove buffer name when it makes sense
          if ! exists('g:patchreview_persist')
            setlocal buftype=nofile
            silent! 0f
          endif
          let &filetype = l:filetype
          let &fdm = 'diff'
          if has('folding')
            let &foldlevel=s:foldlevel
          endif
          wincmd p
          let &modeline=s:keep_modeline
        else
          if s:disable_syntax
            syn off
          else
            syn enable
          endif
          silent! exe s:vsplit . ' new'
          let &filetype = l:filetype
          let &fdm = 'diff'
          if has('folding')
            let &foldlevel=s:foldlevel
          endif
          wincmd p
        endif
      endif
      if ! filereadable(l:stripped_rel_path)
        if patch.type != '-' && patch.type != '+'
          call s:me.buflog('ERROR: Original file ' . l:stripped_rel_path . ' does not exist.')
        endif
        " modelines in loaded files mess with diff comparison
        let s:keep_modeline=&modeline
        let &modeline=0
        if s:disable_syntax
          syn off
        else
          syn enable
        endif
        silent! exe s:noautocmd . 'topleft split ' . fnameescape(l:tmp_patch)
        setlocal noswapfile
        if s:disable_syntax
          syn off
        else
          syn enable
        endif
        setlocal bufhidden=delete
        setlocal nobuflisted
        setlocal modifiable
        setlocal nowrap
        " Remove buffer name when it makes sense
        if ! exists('g:patchreview_persist') && (patch.type != '+' || s:reviewmode != 'patch')
          setlocal buftype=nofile
          silent! 0f
        endif
        if has('folding')
          let &foldlevel=s:foldlevel
        endif
        wincmd p
        let &modeline=s:keep_modeline
      endif
      if filereadable(l:tmp_patched_rej)
        " modelines in loaded files mess with diff comparison
        let s:keep_modeline=&modeline
        let &modeline=0
        if s:disable_syntax
          syn off
        else
          syn enable
        endif
        silent! exe 'topleft split ' . fnameescape(l:tmp_patched_rej)
        " Try to convert rejects to unified format unless explicitly disabled
        if (! exists('g:patchreview_unified_rejects') || g:patchreview_unified_rejects == 1) &&
              \ getline(1) =~ '\m\*\{15}'
          if s:executable('filterdiff')
            call append(0, '--- ' . l:stripped_rel_path . '.new')
            call append(0, '*** ' . l:stripped_rel_path . '.old')
            silent %!filterdiff --format=unified
          elseif ! l:filterdiff_warned
            if exists('g:patchreview_unified_rejects')
              call s:me.buflog('WARNING: Option g:patchreview_unified_rejects requires filterdiff')
              call s:me.buflog('WARNING: installed which I could not locate on the PATH.')
              call s:me.buflog('WARNING: Please install it via diffutils package for your platform and make')
              call s:me.buflog('WARNING: sure it is on the PATH.')
            else
              call s:me.buflog('WARNING: Converting rejections to unified format requires filterdiff installed')
              call s:me.buflog('WARNING: which I could not locate on the PATH.')
              call s:me.buflog('WARNING: Please install it via diffutils package for your platform and make')
              call s:me.buflog('WARNING: sure it is on the PATH for better readable .rej output.')
            endif
            let l:filterdiff_warned = 1
          endif
        endif
        setlocal noswapfile
        if s:disable_syntax
          syn off
        else
          syn enable
        endif
        setlocal bufhidden=delete
        setlocal nobuflisted
        setlocal modifiable
        setlocal nowrap
        " Remove buffer name
        if ! exists('g:patchreview_persist')
          setlocal buftype=nofile
          silent! 0f
        endif
        if has('folding')
          let &foldlevel=s:foldlevel
        endif
        wincmd p
        let &modeline=s:keep_modeline
        call s:me.buflog(l:msgtype . '*** REJECTED *** ' . l:relpath)
        call s:wiggle(l:tmp_patched, l:tmp_patched_rej)
      endif
    finally
      if ! exists('g:patchreview_persist')
        call delete(l:tmp_patch)
        call delete(l:tmp_patched)
        call delete(l:tmp_patched_rej)
      endif
      unlet! patch
    endtry
  endfor
  call s:me.buflog('-----')
  call s:me.buflog('Done.', 0)
  unlet! g:patches
endfunction
"}}}
function! patchreview#diff_review(...) " {{{
  let l:callback_args = ['Diff Review'] + deepcopy(a:000)
  if exists('g:patchreview_prefunc')
    call call(g:patchreview_prefunc, l:callback_args)
  endif
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o' | augroup! patchreview_plugin
  augroup end

  let s:save_shortmess = &shortmess
  let s:save_aw = &autowrite
  let s:save_awa = &autowriteall
  let s:origtabpagenr = tabpagenr()
  let s:equalalways = &equalalways
  let s:eadirection = &eadirection
  set equalalways
  set eadirection=hor
  set shortmess=aW
  set shortmess=aW
  call s:wipe_message_buffer()

  try
    if a:0 != 0  " :DiffReview some command with arguments
      let l:outfile = s:temp_name()
      if a:1 =~ '^\d\+$'
        " DiffReview strip_count command
        let l:cmd = join(map(deepcopy(a:000[1:]), 'shellescape(v:val)') + ['>', shellescape(l:outfile)], ' ')
        let l:binary = copy(a:000[1])
        let l:strip_count = eval(a:1)
      else
        let l:cmd = join(map(deepcopy(a:000), 'shellescape(v:val)') + ['>', shellescape(l:outfile)], ' ')
        let l:binary = copy(a:000[0])
        let l:strip_count = 0   " fake it
      endif
      let v:errmsg = ''
      let l:cout = system(l:cmd)
      if v:errmsg == '' &&
            \  (a:0 != 0 && l:binary =~ '^\(cvs\|diff\|bzr\)$')
            \ && v:shell_error == 1
        " Ignoring diff and CVS non-error
      elseif v:errmsg != '' || v:shell_error
        call s:me.buflog(v:errmsg)
        call s:me.buflog('Could not execute [' . l:cmd . ']')
        if v:shell_error
          call s:me.buflog('Error code: ' . v:shell_error)
        endif
        call s:me.buflog(l:cout)
        call s:me.buflog('Diff review aborted.')
        return
      endif
      let s:reviewmode = 'diff'
      let l:lines = patchreview#get_patchfile_lines(l:outfile)
      call s:generic_review([l:lines, l:strip_count])
    else  " :DiffReview
      call s:init_diff_modules()
      let l:diff = {}
      for module in keys(s:modules)
        if s:modules[module].detect()
          let l:diff = s:modules[module].get_diff()
          "call s:me.debug('Detected ' . module)
          break
        endif
      endfor
      if !exists("l:diff['diff']") || empty(l:diff['diff'])
        call s:me.buflog('No diff found. Make sure you are in a VCS controlled top directory.')
      else
        let s:reviewmode = 'diff'
        call s:generic_review([l:diff['diff'], l:diff['strip']])
      endif
    endif
  finally
    if exists('l:outfile') && ! exists('g:patchreview_persist')
      call delete(l:outfile)
    endif
    unlet! l:diff
    let &eadirection = s:eadirection
    let &equalalways = s:equalalways
    let &autowriteall = s:save_awa
    let &autowrite = s:save_aw
    let &shortmess = s:save_shortmess
  endtry
  if exists('g:patchreview_postfunc')
    call call(g:patchreview_postfunc, l:callback_args)
  endif
endfunction
"}}}
function! s:init_diff_modules() " {{{
  if ! empty(s:modules)
    return
  endif
  for name in map(split(globpath(&runtimepath,
        \ 'autoload/patchreview/*.vim'), '[\n\r]'),
        \ 'fnamemodify(v:val, ":t:r")')

    let l:module = patchreview#{name}#register(s:me)
    if !empty(l:module) && !has_key(s:modules, name)
      let s:modules[name] = l:module
    endif
    unlet l:module
  endfor
endfunction
"}}}
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
" }}}
