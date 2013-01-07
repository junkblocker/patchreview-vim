" VIM plugin for doing single, multi-patch or diff code reviews             {{{
" Home:  http://www.vim.org/scripts/script.php?script_id=1563

" Version       : 1.0.6                                                     {{{
" Author        : Manpreet Singh < junkblocker@yahoo.com >
" Copyright     : 2006-2013 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"
" Changelog :
"
"   1.0.6 - Convert rejects to unified format if possible
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

" TODO {{{
" 1) git staged support?
" }}}
"
" Documentation:                                                         "{{{
" ===========================================================================
" This plugin allows single or multiple, patch or diff based code reviews to
" be easily done in VIM. VIM has :diffpatch command to do single file reviews
" but a) can not handle patch files containing multiple patches or b) do
" automated diff generation for various version control systems. This plugin
" attempts to provide those functionalities. It opens each changed / added or
" removed file diff in new tabs.
"
" Installing:
"
"   For a quick start, unzip patchreview.zip into your ~/.vim directory and
"   restart Vim.
"
" Details:
"
"   Requirements:
"
"   1) VIM 7.0 or higher built with +diff option.
"
"   2) A gnu compatible patch command installed. This is the standard patch
"      command on Linux, Mac OS X, *BSD, Cygwin or /usr/bin/gpatch on newer
"      Solaris.
"
"   Install:
"
"   1) Extract the zip in your $HOME/.vim or $VIM/vimfiles directory and
"      restart vim. The  directory location relevant to your platform can be
"      seen by running :help add-global-plugin in vim.
"
"   2) Restart vim.
"
"  Configuration:
"
"  Optionally, specify the locations to the patch command in your .vimrc.
"
"      let g:patchreview_patch       = '/path/to/gnu/patch'
"
" Usage:
"
"  Please see :help patchreview or :help diffreview for details.
"
""}}}

" Enabled only during development
" unlet! g:loaded_patchreview
" unlet! g:patchreview_patch
" let g:patchreview_patch = 'patch'

" load only once
if &cp
  finish
endif
if v:version < 700
  finish
endif

let s:msgbufname = '--PatchReview_Messages--'

let s:me = {}

let s:modules = {}

" Functions {{{

function! s:me.Status(str)                                                 "{{{
  if v:version >= 703
    let l:wide = min([strlen(a:str), strdisplaywidth(a:str)])
  else
    let l:wide = min([strlen(a:str), &columns])
  endif
  echo strpart(a:str, 0, l:wide)
  " call s:me.Debug(strpart(a:str, 0, l:wide))
  sleep 1m
  redraw
endfunction
" }}}

function! s:me.Debug(str)                                                  "{{{
  if exists('g:patchreview_debug')
    call s:me.Echo('DEBUG: ' . a:str)
  endif
endfunction
command! -nargs=+ -complete=expression PRDebug call s:PRDebug(<args>)
"}}}

function! <SID>WipeMsgBuf()                                            "{{{
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

function! s:me.Echo(...)                                                   "{{{
  " Usage: s:me.Echo(msg, [go_back])
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
    let bufnum = bufnr(s:msgbufname)
    let wcmd = bufnum == -1 ? s:msgbufname : '+buffer' . bufnum
    exe 'silent! botright 5split ' . wcmd
    let s:msgbuftabnr = tabpagenr()
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
  endif
  setlocal modifiable
  if a:0 != 0
    silent! $put =a:1
  endif
  normal! G
  setlocal nomodifiable
  exe l:msgtab_orgwinnr . 'wincmd w'
  if a:0 == 1 ||  a:0 > 1 && a:2 != 0
    exe ':tabnext ' . l:cur_tabnr
    if l:cur_winnr != -1 && winnr() != l:cur_winnr
      exe l:cur_winnr . 'wincmd w'
    endif
  endif
endfunction
"}}}

function! <SID>CheckBinary(BinaryName)                                 "{{{
  " Verify that BinaryName is specified or available
  if ! exists('g:patchreview_' . a:BinaryName)
    if executable(a:BinaryName)
      let g:patchreview_{a:BinaryName} = a:BinaryName
      return 1
    else
      call s:me.Echo('g:patchreview_' . a:BinaryName . ' is not defined and ' . a:BinaryName . ' command could not be found on path.')
      call s:me.Echo('Please define it in your .vimrc.')
      return 0
    endif
  elseif ! executable(g:patchreview_{a:BinaryName})
    call s:me.Echo('Specified g:patchreview_' . a:BinaryName . ' [' . g:patchreview_{a:BinaryName} . '] is not executable.')
    return 0
  else
    return 1
  endif
endfunction
"}}}

function! <SID>GuessStrip(diff_file_path, default_strip) " {{{
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
        " call s:me.Debug("Guessing strip: " . i)
        return
      endif
    endif
    let i = i + 1
  endwhile
  " call s:me.Debug("REALLY Guessing strip: " . a:default_strip)
  let s:guess_strip[a:default_strip] += 1
endfunction
" }}}

function! <SID>PRState(...)  " For easy manipulation of diff parsing state "{{{
  if a:0 != 0
    let s:STATE = a:1
    " call s:me.Debug('Set STATE: ' . a:1)
  else
    if ! exists('s:STATE')
      let s:STATE = 'START'
    endif
    return s:STATE
  endif
endfunction
command! -nargs=* PRState call s:PRState(<args>)
"}}}

function! <SID>TempName()
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

function! <SID>GetPatchFileLines(patchfile)
  "
  " Throws: "File " . a:patchfile . " is not readable"
  "
  let l:patchfile = expand(a:patchfile, ":p")
  if ! filereadable(expand(l:patchfile))
    throw "File " . l:patchfile . " is not readable"
    return
  endif
  return readfile(l:patchfile, 'b')
endfunction

function! s:me.GenDiff(shell_escaped_cmd)
  let l:diff = []
  let v:errmsg = ''
  let l:cout = system(a:shell_escaped_cmd)
  if v:errmsg != '' || v:shell_error
    call s:me.Echo(v:errmsg)
    call s:me.Echo('Could not execute [' . a:shell_escaped_cmd . ']')
    if v:shell_error
      call s:me.Echo('Error code: ' . v:shell_error)
    endif
    call s:me.Echo(l:cout)
  else
    let l:diff = split(l:cout, '[\n\r]')
  endif
  return l:diff
endfunction

function! <SID>ExtractDiffs(lines, default_strip_count)               "{{{
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
  let l:linescount = len(a:lines)
  PRState 'START'
  while l:line_num < l:linescount
    let l:line = a:lines[l:line_num]
    " call s:me.Debug(l:line)
    let l:line_num += 1
    if s:PRState() == 'START' " {{{
      let l:mat = matchlist(l:line, '^--- \([^\t]\+\).*$')
      if ! empty(l:mat) && l:mat[1] != ''
        PRState 'MAYBE_UNIFIED_DIFF'
        let l:p_first_file = l:mat[1]
        let l:collect = [l:line]
        continue
      endif
      let l:mat = matchlist(l:line, '^\*\*\* \([^\t]\+\).*$')
      if ! empty(l:mat) && l:mat[1] != ''
        PRState 'MAYBE_CONTEXT_DIFF'
        let l:p_first_file = l:mat[1]
        let l:collect = [l:line]
        continue
      endif
      let l:mat = matchlist(l:line, '^\(Binary files\|Files\) \(.\+\) and \(.+\) differ$')
      if ! empty(l:mat) && l:mat[2] != '' && l:mat[3] != ''
        call s:me.Echo('Ignoring ' . tolower(l:mat[1]) . ' ' . l:mat[2] . ' and ' . l:mat[3])
        continue
      endif
      " Note - Older Perforce (around 2006) generates incorrect diffs
      let l:thisp = escape(expand(getcwd(), ':p'), '\') . '/'
      let l:mat = matchlist(l:line, '^====.*\#\(\d\+\).*' . l:thisp . '\(.*\)\s====\( content\)\?\r\?$')
      if ! empty(l:mat) && l:mat[2] != ''
        let l:p_type = '!'
        let l:filepath = l:mat[2]
        call s:me.Status('Collecting ' . l:filepath)
        let l:collect = ['--- ' . l:filepath . ' (revision ' . l:mat[1] . ')', '+++ ' .  l:filepath . ' (working copy)']
        PRState 'EXPECT_UNIFIED_RANGE_CHUNK'
        continue
      endif
      continue
      " }}}
    elseif s:PRState() == 'MAYBE_CONTEXT_DIFF' " {{{
      let l:mat = matchlist(l:line, '^--- \([^\t]\+\).*$')
      if empty(l:mat) || l:mat[1] == ''
        PRState 'START'
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
          if l:p_first_file =~ '^//'  " A Perforce diff
            let l:filepath = l:p_second_file
          else
            let l:filepath = l:p_first_file
          endif
        endif
      endif
      call s:me.Status('Collecting ' . l:filepath)
      PRState 'EXPECT_15_STARS'
      let l:collect += [l:line]
      " }}}
    elseif s:PRState() == 'EXPECT_15_STARS' " {{{
      if l:line !~ '^*\{15}$'
        PRState 'START'
        let l:line_num -= 1
        continue
      endif
      PRState 'EXPECT_CONTEXT_CHUNK_HEADER_1'
      let l:collect += [l:line]
      " }}}
    elseif s:PRState() == 'EXPECT_CONTEXT_CHUNK_HEADER_1' " {{{
      let l:mat = matchlist(l:line, '^\*\*\* \(\d\+,\)\?\(\d\+\) \*\*\*\*$')
      if empty(l:mat) || l:mat[1] == ''
        PRState 'START'
        let l:line_num -= 1
        continue
      endif
      let l:collect += [l:line]
      PRState 'READ_TILL_CONTEXT_FRAGMENT_2'
      continue
      " }}}
    elseif s:PRState() == 'READ_TILL_CONTEXT_FRAGMENT_2' " {{{
      if l:line !~ '^[ !+-] .*$'
        let l:mat = matchlist(l:line, '^--- \(\d\+\),\(\d\+\) ----$')
        if ! empty(l:mat) && l:mat[1] != '' && l:mat[2] != ''
          let goal_count = l:mat[2] - l:mat[1] + 1
          let c_count = 0
          PRState 'READ_CONTEXT_CHUNK'
          let l:collect += [l:line]
          continue
        endif
        PRState 'START'
        let l:line_num -= 1
        continue
      endif
      let l:collect += [l:line]
      continue
      " }}}
    elseif s:PRState() == 'READ_CONTEXT_CHUNK' " {{{
      let c_count += 1
      if c_count == goal_count
        let l:collect += [l:line]
        PRState 'BACKSLASH_OR_CRANGE_EOF'
        continue
      else " goal not met yet
        let l:mat = matchlist(l:line, '^\([\\!+ -]\) .*$')
        if empty(l:mat) || l:mat[1] == ''
          if l:line =~ '^\*\{15}$'
            let l:collect += [l:line]
            PRState 'EXPECT_CONTEXT_CHUNK_HEADER_1'
            continue
          else
            let l:line_num -= 1
            PRState 'START'
            continue
          endif
        endif
        let l:collect += [l:line]
        continue
      endif
      " }}}
    elseif s:PRState() == 'BACKSLASH_OR_CRANGE_EOF' " {{{
      if l:line =~ '^\\ No newline.*$'   " XXX: Can we go to another chunk from here??
        let l:collect += [l:line]
        let l:this_patch = {}
        let l:this_patch['filename'] = l:filepath
        let l:this_patch['type'] = l:p_type
        let l:this_patch['content'] = l:collect
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        call s:me.Status('Collected  ' . l:filepath)
        if l:p_type == '!'
          call s:GuessStrip(l:filepath, a:default_strip_count)
        endif
        PRState 'START'
        continue
      endif
      if l:line =~ '^\*\{15}$'
        let l:collect += [l:line]
        PRState 'EXPECT_CONTEXT_CHUNK_HEADER_1'
        continue
      endif
      let l:this_patch = {'filename': l:filepath, 'type':  l:p_type, 'content':  l:collect}
      let g:patches['patch'] += [l:this_patch]
      unlet! l:this_patch
      let l:line_num -= 1
      call s:me.Status('Collected  ' . l:filepath)
      if l:p_type == '!'
        call s:GuessStrip(l:filepath, a:default_strip_count)
      endif
      PRState 'START'
      continue
      " }}}
    elseif s:PRState() == 'MAYBE_UNIFIED_DIFF' " {{{
      let l:mat = matchlist(l:line, '^+++ \([^\t]\+\).*$')
      if empty(l:mat) || l:mat[1] == ''
        PRState 'START'
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
      call s:me.Status('Collecting ' . l:filepath)
      PRState 'EXPECT_UNIFIED_RANGE_CHUNK'
      let l:collect += [l:line]
      continue
      " }}}
    elseif s:PRState() == 'EXPECT_UNIFIED_RANGE_CHUNK' "{{{
      let l:mat = matchlist(l:line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
      if ! empty(l:mat)
        let l:old_goal_count = l:mat[2]
        let l:new_goal_count = l:mat[4]
        let l:o_count = 0
        let l:n_count = 0
        PRState 'READ_UNIFIED_CHUNK'
        let l:collect += [l:line]
      else
        let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        call s:me.Status('Collected  ' . l:filepath)
        if l:p_type == '!'
          call s:GuessStrip(l:filepath, a:default_strip_count)
        endif
        PRState 'START'
        let l:line_num -= 1
      endif
      continue
      "}}}
    elseif s:PRState() == 'READ_UNIFIED_CHUNK' " {{{
      if l:o_count == l:old_goal_count && l:n_count == l:new_goal_count
        if l:line =~ '^\\.*$'   " XXX: Can we go to another chunk from here??
          let l:collect += [l:line]
          let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
          let g:patches['patch'] += [l:this_patch]
          unlet! l:this_patch
          call s:me.Status('Collected  ' . l:filepath)
          if l:p_type == '!'
            call s:GuessStrip(l:filepath, a:default_strip_count)
          endif
          PRState 'START'
          continue
        endif
        let l:mat = matchlist(l:line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
        if ! empty(l:mat)
          let l:old_goal_count = l:mat[2]
          let l:new_goal_count = l:mat[4]
          let l:o_count = 0
          let l:n_count = 0
          let l:collect += [l:line]
          continue
        endif
        let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        call s:me.Status('Collected  ' . l:filepath)
        if l:p_type == '!'
          call s:GuessStrip(l:filepath, a:default_strip_count)
        endif
        let l:line_num -= 1
        PRState 'START'
        continue
      else " goal not met yet
        let l:mat = matchlist(l:line, '^\([\\+ -]\).*$')
        if empty(l:mat) || l:mat[1] == ''
          let l:line_num -= 1
          PRState 'START'
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
  "call s:me.Echo(s:PRState())
  if (
        \ (s:PRState() == 'READ_CONTEXT_CHUNK'
        \  && c_count == goal_count
        \ ) ||
        \ (s:PRState() == 'READ_UNIFIED_CHUNK'
        \  && l:n_count == l:new_goal_count
        \  && l:o_count == l:old_goal_count
        \ )
        \)
    let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
    let g:patches['patch'] += [l:this_patch]
    unlet! l:this_patch
    unlet! lines
    call s:me.Status('Collected  ' . l:filepath)
    if l:p_type == '!' || (l:p_type == '+' && s:reviewmode == 'diff')
      call s:GuessStrip(l:filepath, a:default_strip_count)
    endif
  endif
  return
endfunction
"}}}

function! patchreview#PatchReview(...)                                     "{{{
  if exists('g:patchreview_prefunc')
    call call(g:patchreview_prefunc, ['Patch Review'])
  endif
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o'
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
  call s:WipeMsgBuf()
  let s:reviewmode = 'patch'
  try
    let l:lines = s:GetPatchFileLines(a:1)
    call s:_GenericReview([l:lines] + a:000[1:])
  catch /.*/
    call s:me.Echo('ERROR: ' . v:exception)
  endtry
  let &eadirection = s:eadirection
  let &equalalways = s:equalalways
  let &autowriteall = s:save_awa
  let &autowrite = s:save_aw
  let &shortmess = s:save_shortmess
  augroup! patchreview_plugin
  if exists('g:patchreview_postfunc')
    call call(g:patchreview_postfunc, ['Patch Review'])
  endif
endfunction
"}}}

function! patchreview#ReversePatchReview(...)  "{{{
  if exists('g:patchreview_prefunc')
    call call(g:patchreview_prefunc, ['Reverse Patch Review'])
  endif
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o'
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
  call s:WipeMsgBuf()
  let s:reviewmode = 'rpatch'
  try
    let l:lines = s:GetPatchFileLines(a:1)
    call s:_GenericReview([l:lines] + a:000[1:])
  catch /.*/
    call s:me.Echo('ERROR: ' . v:exception)
  endtry
  let &eadirection = s:eadirection
  let &equalalways = s:equalalways
  let &autowriteall = s:save_awa
  let &autowrite = s:save_aw
  let &shortmess = s:save_shortmess
  augroup! patchreview_plugin
  if exists('g:patchreview_postfunc')
    call call(g:patchreview_postfunc, ['Reverse Patch Review'])
  endif
endfunction
"}}}

function! <SID>Wiggle(out, rej) " {{{
  if ! executable('wiggle')
    return
  endif
  let l:wiggle_out = s:TempName()
  let v:errmsg = ''
  let l:cout = system('wiggle --merge ' . shellescape(a:out) . ' ' . shellescape(a:rej) . ' > ' . shellescape(l:wiggle_out))
  if v:errmsg != '' || v:shell_error
    call s:me.Echo('ERROR: Wiggle was not completely successful.')
    if v:errmsg != ''
      call s:me.Echo('ERROR: ' . v:errmsg)
    endif
  endif
  if filereadable(l:wiggle_out)
    " modelines in loaded files mess with diff comparison
    let s:keep_modeline=&modeline
    let &modeline=0
    silent! exe 'vert diffsplit ' . fnameescape(l:wiggle_out)
    setlocal noswapfile
    setlocal syntax=none
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
    wincmd w
  endif
endfunction
" }}}

function! <SID>_GenericReview(argslist)                                   "{{{
  " diff mode:
  "   arg1 = patchlines
  "   arg2 = strip count
  " patch mode:
  "   arg1 = patchlines
  "   arg2 = directory
  "   arg3 = strip count

  " VIM 7+ required
  if version < 700
    call s:me.Echo('This plugin needs VIM 7 or higher')
    return
  endif

  " +diff required
  if ! has('diff')
    call s:me.Echo('This plugin needs VIM built with +diff feature.')
    return
  endif

  if s:reviewmode == 'diff' || s:reviewmode == 'rpatch'
    let patch_R_options = ['-t', '-R']
  elseif s:reviewmode == 'patch'
    let patch_R_options = []
  else
    call s:me.Echo('Fatal internal error in patchreview.vim plugin')
    return
  endif

  " ----------------------------- patch ------------------------------------
  if s:reviewmode =~ 'patch'
    let l:argc = len(a:argslist)
    if l:argc == 0 || l:argc > 3
      if s:reviewmode == 'patch'
        call s:me.Echo('PatchReview command needs 1 to 3 arguments.')
        return
      endif
      if s:reviewmode == 'rpatch'
        call s:me.Echo('ReversePatchReview command needs 1 to 3 arguments.')
        return
      endif
    endif
    " ARG[0]: patchlines
    let l:patchlines = a:argslist[0]
    " ARG[1]: directory [optional]
    if len(a:argslist) >= 2
      let s:src_dir = expand(a:argslist[1], ':p')
      if ! isdirectory(s:src_dir)
        call s:me.Echo('[' . s:src_dir . '] is not a directory')
        return
      endif
      try
        exe 'cd ' . fnameescape(s:src_dir)
      catch /^.*E344.*/
        call s:me.Echo('Could not change to directory [' . s:src_dir . ']')
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
      call s:me.Echo('Fatal internal error in patchreview.vim plugin')
      return
    endif
    let l:patchlines = a:argslist[0]
    " passed in by default
    let l:strip_count = eval(a:argslist[1])
  else
    call s:me.Echo('Fatal internal error in patchreview.vim plugin')
  endif " diff

  " Verify that patch command and temporary directory are available or specified
  if ! s:CheckBinary('patch')
    return
  endif

  call s:me.Echo('Source directory: ' . getcwd())
  call s:me.Echo('------------------')
  if exists('l:strip_count')
    let l:defsc = l:strip_count
  elseif s:reviewmode =~ 'patch'
    let l:defsc = 1
  else
    call s:me.Echo('Fatal internal error in patchreview.vim plugin')
  endif
  try
    call s:ExtractDiffs(l:patchlines, l:defsc)
  catch
    call s:me.Echo('Exception ' . v:exception)
    call s:me.Echo('From ' . v:throwpoint)
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
    call s:me.Status('Processing ' . l:this_patch_num . '/' . l:total_patches . ' ' . patch.filename)
    if patch.type !~ '^[!+-]$'
      call s:me.Echo('*** Skipping review generation due to unknown change [' . patch.type . ']')
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
        let msgtype = 'Patch modifies file: '
      elseif s:reviewmode == 'diff'
        let msgtype = 'File has changes: '
      endif
    elseif patch.type == '+'
      if s:reviewmode =~ 'patch'
        let msgtype = 'Patch adds file    : '
      elseif s:reviewmode == 'diff'
        let msgtype = 'New file        : '
      endif
    elseif patch.type == '-'
      if s:reviewmode =~ 'patch'
        let msgtype = 'Patch removes file : '
      elseif s:reviewmode == 'diff'
        let msgtype = 'Removed file    : '
      endif
    endif
    let bufnum = bufnr(l:relpath)
    if buflisted(bufnum) && getbufvar(bufnum, '&mod')
      call s:me.Echo('Old buffer for file [' . l:relpath . '] exists in modified state. Skipping review.')
      continue
      unlet! patch
    endif
    let l:tmp_patch = s:TempName()
    let l:tmp_patched = s:TempName()
    let l:tmp_patched_rej = l:tmp_patched . '.rej'  " Rejection file created by patch

    try
      " write patch for patch.filename into l:tmp_patch
      " some ports of GNU patch (e.g. UnxUtils) always want DOS end of line in
      " patches while correctly handling any EOLs in files
      if exists("g:patchreview_patch_needs_crlf") && g:patchreview_patch_needs_crlf
        call map(patch.content, 'v:val . "\r"')
      endif
      if writefile(patch.content, l:tmp_patch) != 0
        call s:me.Echo('*** ERROR: Could not save patch to a temporary file.')
        continue
      endif
      "if exists('g:patchreview_debug')
      "  exe ':tabedit ' . l:tmp_patch
      "endif
      if patch.type == '+' && s:reviewmode =~ 'patch'
        let l:inputfile = ''
        if filereadable('/etc/rc.conf')
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
      elseif patch.type == '+' && s:reviewmode == 'diff'
        let l:inputfile = ''
        unlet! l:patchcmd
      else
        let l:inputfile = expand(l:stripped_rel_path, ':p')
        if filereadable('/etc/rc.conf')
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
      if exists('l:patchcmd')
        let v:errmsg = ''
        let l:pout = system(l:patchcmd)
        if v:errmsg != '' || v:shell_error
          let error = 1
          call s:me.Echo('ERROR: Could not execute patch command.')
          call s:me.Echo('ERROR:     ' . l:patchcmd)
          if l:pout != ''
            call s:me.Echo('ERROR: ' . l:pout)
          endif
          call s:me.Echo('ERROR: ' . v:errmsg)
          if filereadable(l:tmp_patched)
            call s:me.Echo('ERROR: Diff partially shown.')
          else
            call s:me.Echo('ERROR: Diff skipped.')
          endif
        endif
      endif
      "if expand('%') == '' && line('$') == 1 && getline(1) == '' && ! &modified && ! &diff
        "silent! exe 'edit ' . l:stripped_rel_path
      "else
        silent! exe 'tabedit ' . fnameescape(l:stripped_rel_path)
      "endif
      let l:winnum = winnr()
      if ! error || filereadable(l:tmp_patched)
        let l:filetype = &filetype
        if exists('l:patchcmd')
          " modelines in loaded files mess with diff comparison
          let s:keep_modeline=&modeline
          let &modeline=0
          silent! exe 'vert diffsplit ' . fnameescape(l:tmp_patched)
          setlocal noswapfile
          setlocal syntax=none
          setlocal bufhidden=delete
          setlocal nobuflisted
          setlocal modifiable
          setlocal nowrap
          " Remove buffer name
          if ! exists('g:patchreview_persist')
            setlocal buftype=nofile
            silent! 0f
          endif
          let &filetype = l:filetype
          let &fdm = 'diff'
          wincmd p
          let &modeline=s:keep_modeline
        else
          silent! vnew
          let &filetype = l:filetype
          let &fdm = 'diff'
          wincmd p
        endif
      endif
      if ! filereadable(l:stripped_rel_path)
        call s:me.Echo('ERROR: Original file ' . l:stripped_rel_path . ' does not exist.')
        " modelines in loaded files mess with diff comparison
        let s:keep_modeline=&modeline
        let &modeline=0
        silent! exe 'topleft split ' . fnameescape(l:tmp_patch)
        setlocal noswapfile
        setlocal syntax=none
        setlocal bufhidden=delete
        setlocal nobuflisted
        setlocal modifiable
        setlocal nowrap
        " Remove buffer name
        if ! exists('g:patchreview_persist')
          setlocal buftype=nofile
          silent! 0f
        endif
        wincmd p
        let &modeline=s:keep_modeline
      endif
      if filereadable(l:tmp_patched_rej)
        " modelines in loaded files mess with diff comparison
        let s:keep_modeline=&modeline
        let &modeline=0
        silent! exe 'topleft split ' . fnameescape(l:tmp_patched_rej)
        if getline(1) =~ '\m\*\{15}' && executable('filterdiff')
          call append(0, '--- ' . l:stripped_rel_path . '.new')
          call append(0, '*** ' . l:stripped_rel_path . '.old')
          silent %!filterdiff --format=unified
        endif
        setlocal noswapfile
        setlocal syntax=none
        setlocal bufhidden=delete
        setlocal nobuflisted
        setlocal modifiable
        setlocal nowrap
        " Remove buffer name
        if ! exists('g:patchreview_persist')
          setlocal buftype=nofile
          silent! 0f
        endif
        wincmd p
        let &modeline=s:keep_modeline
        call s:me.Echo(msgtype . '*** REJECTED *** ' . l:relpath)
        call s:Wiggle(l:tmp_patched, l:tmp_patched_rej)
      else
        call s:me.Echo(msgtype . ' ' . l:relpath)
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
  call s:me.Echo('-----')
  call s:me.Echo('Done.', 0)
  unlet! g:patches
endfunction
"}}}

function! patchreview#DiffReview(...) " {{{
  if exists('g:patchreview_prefunc')
    call call(g:patchreview_prefunc, ['Diff Review'])
  endif
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o'
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
  call s:WipeMsgBuf()

  try
    if a:0 != 0  " :DiffReview some command with arguments
      let l:outfile = s:TempName()
      if a:1 =~ '^\d+$'
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
            \  (a:0 != 0 && l:binary =~ '^\(cvs\|diff\)$')
            \ && v:shell_error == 1
        " Ignoring diff and CVS non-error
      elseif v:errmsg != '' || v:shell_error
        call s:me.Echo(v:errmsg)
        call s:me.Echo('Could not execute [' . l:cmd . ']')
        if v:shell_error
          call s:me.Echo('Error code: ' . v:shell_error)
        endif
        call s:me.Echo(l:cout)
        call s:me.Echo('Diff review aborted.')
        return
      endif
      let s:reviewmode = 'diff'
      let l:lines = s:GetPatchFileLines(l:outfile)
      call s:_GenericReview([l:lines, l:strip_count])
    else  " :DiffReview
      call s:InitDiffModules()
      let l:diff = {}
      for module in keys(s:modules)
        if s:modules[module].Detect()
          let l:diff = s:modules[module].GetDiff()
          "call s:me.Debug('Detected ' . module)
          break
        endif
      endfor
      if !exists("l:diff['diff']") || empty(l:diff['diff'])
        call s:me.Echo('Please make sure you are in a VCS controlled top directory.')
      else
        let s:reviewmode = 'diff'
        call s:_GenericReview([l:diff['diff'], l:diff['strip']])
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
    augroup! patchreview_plugin
  endtry
  if exists('g:patchreview_postfunc')
    call call(g:patchreview_postfunc, ['Diff Review'])
  endif
endfunction
"}}}

function! <SID>InitDiffModules() " {{{
  if ! empty(s:modules)
    return
  endif
  for name in map(split(globpath(&runtimepath,
        \ 'autoload/patchreview/*.vim'), '[\n\r]'),
        \ 'fnamemodify(v:val, ":t:r")')

    let module = patchreview#{name}#register(s:me)
    if !empty(module) && !has_key(s:modules, name)
      let s:modules[name] = module
    endif
    unlet module
  endfor
endfunction
"}}}

" modeline
" vim: set et fdl=4 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
