" VIM plugin for doing single, multi-patch or diff code reviews {{{
" Home:  http://www.vim.org/scripts/script.php?script_id=1563

" Version       : 0.4                                                     "{{{
" Author        : Manpreet Singh < junkblocker@yahoo.com >
" Copyright     : 2006-2012 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"
" Changelog :
"
"   0.4 - Handle paths with special characters in them
"       - Remove patchutils use completely as we can do more with the pure
"         vim version
"       - Added patchreview_postfunc for long postreview jobs
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
if &cp || (! exists('g:patchreview_debug') && exists('g:loaded_patchreview'))
  finish
endif
if v:version < 700
  finish
endif

let g:loaded_patchreview="0.4"

let s:msgbufname = '--PatchReview_Messages--'

" Functions {{{

function! <SID>PRStatus(str)                                                 "{{{
  let l:wide = min([strlen(a:str), strdisplaywidth(a:str)])
  echo strpart(a:str, 0, l:wide)
  sleep 1m
  redraw
endfunction
command! -nargs=+ -complete=expression PRStatus call s:PRStatus(<args>)
" }}}

function! <SID>PRDebug(str)                                                 "{{{
  if exists('g:patchreview_debug')
    PREcho 'DEBUG: ' . a:str
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

function! <SID>PREcho(...)                                                 "{{{
  " Usage: s:PREcho(msg, [go_back])
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

command! -nargs=+ -complete=expression PREcho call s:PREcho(<args>)
"}}}

function! <SID>CheckBinary(BinaryName)                                 "{{{
  " Verify that BinaryName is specified or available
  if ! exists('g:patchreview_' . a:BinaryName)
    if executable(a:BinaryName)
      let g:patchreview_{a:BinaryName} = a:BinaryName
      return 1
    else
      PREcho 'g:patchreview_' . a:BinaryName . ' is not defined and ' . a:BinaryName . ' command could not be found on path.'
      PREcho 'Please define it in your .vimrc.'
      return 0
    endif
  elseif ! executable(g:patchreview_{a:BinaryName})
    PREcho 'Specified g:patchreview_' . a:BinaryName . ' [' . g:patchreview_{a:BinaryName} . '] is not executable.'
    return 0
  else
    return 1
  endif
endfunction
"}}}


function! <SID>PRState(...)  " For easy manipulation of diff extraction state      "{{{
  if a:0 != 0
    let s:STATE = a:1
"    PRDebug s:STATE
  else
    if ! exists('s:STATE')
      let s:STATE = 'START'
"      PRDebug s:STATE
    endif
    return s:STATE
  endif
endfunction
command! -nargs=* PRState call s:PRState(<args>)
"}}}

function! <SID>ExtractDiffs(...)                                   "{{{
  " Sets g:patches = {'fail':'', 'patch':[
  " {
  "  'filename': filepath
  "  'type'    : '+' | '-' | '!'
  "  'content' : patch text for this file
  " },
  " ...
  " ]}
  let g:patches = {'fail' : '', 'patch' : []}
  " TODO : User pointers into lines list rather then use collect
  if a:0 == 0
    let g:patches['fail'] = "ExtractDiffs expects at least a patchfile argument"
    return
  endif
  let l:patchfile = expand(a:1, ':p')
  if a:0 > 1
    let patch = a:2
  endif
  if ! filereadable(l:patchfile)
    let g:patches['fail'] = "File " . l:patchfile . " is not readable"
    return
  endif
  let l:collect = []
  let l:line_num = 0
  let l:lines = readfile(l:patchfile, "b")
  let l:linescount = len(l:lines)
  PRState 'START'
  while l:line_num < l:linescount
    let l:line = l:lines[l:line_num]
"    PRDebug 'Read: [' . l:line . ']'
    let l:line_num += 1
    if s:PRState() == 'START' " {{{
      let l:mat = matchlist(l:line, '^--- \([^\t]\+\).*$')
      if ! empty(l:mat) && l:mat[1] != ''
        PRState 'MAYBE_UNIFIED_DIFF'
        let p_first_file = l:mat[1]
"        PRDebug 'p_first_file set to ' . p_first_file
        let l:collect = [l:line]
        continue
      endif
      let l:mat = matchlist(l:line, '^\*\*\* \([^\t]\+\).*$')
      if ! empty(l:mat) && l:mat[1] != ''
        PRState 'MAYBE_CONTEXT_DIFF'
        let p_first_file = l:mat[1]
"        PRDebug 'p_first_file set to ' . p_first_file
        let l:collect = [l:line]
        continue
      endif
      continue
      " }}}
    elseif s:PRState() == 'MAYBE_CONTEXT_DIFF' " {{{
      let l:mat = matchlist(l:line, '^--- \([^\t]\+\).*$')
      if empty(l:mat) || l:mat[1] == ''
        PRState 'START'
        let l:line_num -= 1
"        PRDebug 'Back to square one ' . l:line
        continue
      endif
      let l:p_second_file = l:mat[1]
"      PRDebug 'l:p_second_file set to ' . l:p_second_file
      if p_first_file == '/dev/null'
        if l:p_second_file == '/dev/null'
          let g:patches['fail'] = "Malformed diff found at line " . l:line_num
          return
        endif
        let l:p_type = '+'
        let l:filepath = l:p_second_file
"        PRDebug "Patch adds file " . l:filepath
      else
        if l:p_second_file == '/dev/null'
          let l:p_type = '-'
          let l:filepath = p_first_file
"          PRDebug "Patch deletes file " . l:filepath
        else
          let l:p_type = '!'
          let l:filepath = l:p_second_file
        endif
      endif
      PRStatus 'Collecting ' . l:filepath
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
      PRState 'SKIP_CONTEXT_STUFF_1'
      continue
      " }}}
    elseif s:PRState() == 'SKIP_CONTEXT_STUFF_1' " {{{
      if l:line !~ '^[ !+].*$'
        let l:mat = matchlist(l:line, '^--- \(\d\+\),\(\d\+\) ----$')
        if ! empty(l:mat) && l:mat[1] != '' && l:mat[2] != ''
          let goal_count = l:mat[2] - l:mat[1] + 1
          let c_count = 0
          PRState 'READ_CONTEXT_CHUNK'
          let l:collect += [l:line]
"          PRDebug " Goal count set to " . goal_count
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
        let l:mat = matchlist(l:line, '^\([\\!+ ]\).*$')
        if empty(l:mat) || l:mat[1] == ''
          let l:line_num -= 1
          PRState 'START'
          continue
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
        PRStatus 'Collected  ' . l:filepath
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
      PRStatus 'Collected  ' . l:filepath
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
"      PRDebug 'l:p_second_file set to ' . l:p_second_file
      if p_first_file == '/dev/null'
        if l:p_second_file == '/dev/null'
          let g:patches['fail'] = "Malformed diff found at line " . l:line_num
          return
        endif
        let l:p_type = '+'
        let l:filepath = l:p_second_file
"        PRDebug "Patch adds file " . l:filepath
      else
        if l:p_second_file == '/dev/null'
          let l:p_type = '-'
          let l:filepath = p_first_file
"          PRDebug 'Patch deletes file ' . l:filepath
        else
          let l:p_type = '!'
          let l:filepath = l:p_second_file
"          PRDebug 'Patch modifies file ' . l:filepath
        endif
      endif
      PRStatus 'Collecting ' . l:filepath
      PRState 'EXPECT_UNIFIED_RANGE_CHUNK'
      let l:collect += [l:line]
      continue
      " }}}
    elseif s:PRState() == 'EXPECT_UNIFIED_RANGE_CHUNK' "{{{
      let l:mat = matchlist(l:line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
      if ! empty(l:mat)
        let old_goal_count = l:mat[2]
        let new_goal_count = l:mat[4]
        let o_count = 0
        let n_count = 0
"        PRDebug "Goal count set to " . old_goal_count . ', ' . new_goal_count
        PRState 'READ_UNIFIED_CHUNK'
        let l:collect += [l:line]
      else
        let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        PRStatus 'Collected  ' . l:filepath
        PRState 'START'
        let l:line_num -= 1
      endif
      continue
      "}}}
    elseif s:PRState() == 'READ_UNIFIED_CHUNK' " {{{
      if o_count == old_goal_count && n_count == new_goal_count
        if l:line =~ '^\\.*$'   " XXX: Can we go to another chunk from here??
          let l:collect += [l:line]
          let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
          let g:patches['patch'] += [l:this_patch]
          unlet! l:this_patch
          PRStatus 'Collected  ' . l:filepath
          PRState 'START'
          continue
        endif
        let l:mat = matchlist(l:line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
        if ! empty(l:mat)
          let old_goal_count = l:mat[2]
          let new_goal_count = l:mat[4]
          let o_count = 0
          let n_count = 0
"          PRDebug "Goal count set to " . old_goal_count . ', ' . new_goal_count
          let l:collect += [l:line]
          continue
        endif
        let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
        let g:patches['patch'] += [l:this_patch]
        unlet! l:this_patch
        PRStatus 'Collected  ' . l:filepath
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
          let n_count += 1
        endif
        if chr == ' '
          let o_count += 1
          let n_count += 1
        endif
        if chr == '-'
          let o_count += 1
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
  "PREcho s:PRState()
  if (s:PRState() == 'READ_CONTEXT_CHUNK' && c_count == goal_count) || (s:PRState() == 'READ_UNIFIED_CHUNK' && n_count == new_goal_count && o_count == old_goal_count)
    let l:this_patch = {'filename': l:filepath, 'type': l:p_type, 'content': l:collect}
    let g:patches['patch'] += [l:this_patch]
    unlet! l:this_patch
    unlet! lines
    PRStatus 'Collected  ' . l:filepath
  endif
  return
endfunction
"}}}

function! patchreviewlib#PatchReview(...)                                           "{{{
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
  call s:_GenericReview(a:000)
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

function! <SID>_GenericReview(argslist)                                   "{{{
  " diff mode:
  "   arg1 = patchfile
  "   arg2 = strip count
  " patch mode:
  "   arg1 = patchfile
  "   arg2 = directory
  "   arg3 = strip count

  " VIM 7+ required
  if version < 700
    PREcho 'This plugin needs VIM 7 or higher'
    return
  endif

  " +diff required
  if ! has('diff')
    PREcho 'This plugin needs VIM built with +diff feature.'
    return
  endif

  if s:reviewmode == 'diff'
    let patch_R_option = ' -t -R '
  elseif s:reviewmode == 'patch'
    let patch_R_option = ''
  else
    PREcho 'Fatal internal error in patchreview.vim plugin'
    return
  endif

  " Check passed arguments
  if len(a:argslist) == 0
    PREcho 'PatchReview command needs at least one argument specifying a patchfile path.'
    return
  endif
  let l:strip_count = 0
  if len(a:argslist) >= 1 && ((s:reviewmode == 'patch' && len(a:argslist) <= 3) || (s:reviewmode == 'diff' && len(a:argslist) == 2))
    let l:patch_file_path = expand(a:argslist[0], ':p')
    if ! filereadable(l:patch_file_path)
      PREcho 'File [' . l:patch_file_path . '] is not accessible.'
      return
    endif
    if len(a:argslist) >= 2 && s:reviewmode == 'patch'
      let s:src_dir = expand(a:argslist[1], ':p')
      if ! isdirectory(s:src_dir)
        PREcho '[' . s:src_dir . '] is not a directory'
        return
      endif
      try
        exe 'cd ' . fnameescape(s:src_dir)
      catch /^.*E344.*/
        PREcho 'Could not change to directory [' . s:src_dir . ']'
        return
      endtry
    endif
    if s:reviewmode == 'diff'
      " passed in by default
      let l:strip_count = eval(a:argslist[1])
    elseif s:reviewmode == 'patch'
      let l:strip_count = 1
      " optional strip count
      if len(a:argslist) == 3
        let l:strip_count = eval(a:argslist[2])
      endif
    endif
  else
    if s:reviewmode == 'patch'
      PREcho 'PatchReview command needs at most three arguments: patchfile path, optional source directory path and optional strip count.'
    elseif s:reviewmode == 'diff'
      PREcho 'DiffReview command accepts no arguments.'
    endif
    return
  endif

  " Verify that patch command and temporary directory are available or specified
  if ! s:CheckBinary('patch')
    return
  endif

  " Requirements met, now execute
  let l:patch_file_path = fnamemodify(l:patch_file_path, ':p')
  if s:reviewmode == 'patch'
    PREcho 'Patch file      : ' . l:patch_file_path
  endif
  PREcho 'Source directory: ' . getcwd()
  PREcho '------------------'
  call s:ExtractDiffs(l:patch_file_path)
  for patch in g:patches['patch']
    if patch.type !~ '^[!+-]$'
      PREcho '*** Skipping review generation due to unknown change [' . patch.type . ']'
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
      if s:reviewmode == 'patch'
        let msgtype = 'Patch modifies file: '
      elseif s:reviewmode == 'diff'
        let msgtype = 'File has changes: '
      endif
    elseif patch.type == '+'
      if s:reviewmode == 'patch'
        let msgtype = 'Patch adds file    : '
      elseif s:reviewmode == 'diff'
        let msgtype = 'New file        : '
      endif
    elseif patch.type == '-'
      if s:reviewmode == 'patch'
        let msgtype = 'Patch removes file : '
      elseif s:reviewmode == 'diff'
        let msgtype = 'Removed file    : '
      endif
    endif
    let bufnum = bufnr(l:relpath)
    if buflisted(bufnum) && getbufvar(bufnum, '&mod')
      PREcho 'Old buffer for file [' . l:relpath . '] exists in modified state. Skipping review.'
      continue
    endif
    let l:tmp_patch = tempname()
    let l:tmp_patched = tempname()
    let l:tmp_patched_rejected = l:tmp_patched . '.rej'

    try
      " write patch for patch.filename into tmp_patch
      call writefile(patch.content, l:tmp_patch)
      if patch.type == '+' && s:reviewmode == 'patch'
"        PRDebug 'Case 1'
        let l:inputfile = ''
        let patchcmd = '!' . fnameescape(g:patchreview_patch) . patch_R_option . ' -s -o ' . fnameescape(l:tmp_patched) . ' ' . fnameescape(l:inputfile) . ' < ' . fnameescape(l:tmp_patch) . ' 2>/dev/null'
      elseif patch.type == '+' && s:reviewmode == 'diff'
"        PRDebug 'Case 2'
        let l:inputfile = ''
        unlet! patchcmd
      else
"        PRDebug 'Case 3'
        let l:inputfile = expand(l:stripped_rel_path, ':p')
        let patchcmd = '!' . fnameescape(g:patchreview_patch) . patch_R_option . ' -s -o ' . fnameescape(l:tmp_patched) . ' ' . fnameescape(l:inputfile) . ' < ' . fnameescape(l:tmp_patch) . ' 2>/dev/null'
      endif
      let error = 0
      if exists('patchcmd')
        let v:errmsg = ''
"        PRDebug patchcmd
        silent exe patchcmd
        if v:errmsg != '' || v:shell_error
          let error = 1
          PREcho 'ERROR: Could not execute patch command.'
          PREcho 'ERROR:     ' . patchcmd
          PREcho 'ERROR: ' . v:errmsg
          PREcho 'ERROR: Diff skipped.'
        endif
      endif
      let s:origtabpagenr = tabpagenr()
      silent! exe 'tabedit ' . l:stripped_rel_path
      if ! error
        if exists('patchcmd')
          " modelines in loaded files mess with diff comparison
          let s:keep_modeline=&modeline
          let &modeline=0
          silent! exe 'vert diffsplit ' . fnameescape(l:tmp_patched)
          setlocal buftype=nofile
          setlocal noswapfile
          setlocal syntax=none
          setlocal bufhidden=delete
          setlocal nobuflisted
          setlocal modifiable
          setlocal nowrap
          " Remove buffer name
          silent! 0f
          " Switch to original to get a nice tab title
          silent! wincmd p
          let &modeline=s:keep_modeline
        else
          silent! vnew
        endif
      else
        if ! filereadable(l:inputfile)
          PREcho 'ERROR: Original file ' . l:inputfile . ' does not exist.'
        endif
      endif
      if filereadable(l:tmp_patched_rejected)
        silent! exe 'topleft 5split ' . fnameescape(l:tmp_patched_rejected)
        PREcho msgtype . '*** REJECTED *** ' . l:relpath
      else
        PREcho msgtype . ' ' . l:relpath
      endif
    finally
      silent! exe 'tabn ' . s:origtabpagenr
      call delete(l:tmp_patch)
      call delete(l:tmp_patched)
      call delete(l:tmp_patched_rejected)
      unlet! patch
    endtry
  endfor
  PREcho '-----'
  PREcho 'Done.', 0
  unlet! g:patches
endfunction
"}}}

function! patchreviewlib#DiffReview(...)                                            "{{{
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

  let vcsdict = {
                  \'Mercurial'  : {'dir': '.hg',  'binary': 'hg',  'strip': 1, 'diffargs': 'diff'                  },
                  \'Bazaar-NG'  : {'dir': '.bzr', 'binary': 'bzr', 'strip': 0, 'diffargs': 'diff'                  },
                  \'monotone'   : {'dir': '_MTN', 'binary': 'mtn', 'strip': 0, 'diffargs': 'diff --unified'        },
                  \'Subversion' : {'dir': '.svn', 'binary': 'svn', 'strip': 0, 'diffargs': 'diff'                  },
                  \'cvs'        : {'dir': 'CVS',  'binary': 'cvs', 'strip': 0, 'diffargs': '-q diff -u'            },
                  \'git'        : {'dir': '.git', 'binary': 'git', 'strip': 1, 'diffargs': 'diff -p -U5 --no-color'},
                  \}

  unlet! s:the_diff_cmd
  unlet! l:vcs
  if ! exists('g:patchreview_diffcmd')
    for key in keys(vcsdict)
      if isdirectory(vcsdict[key]['dir'])
        if ! s:CheckBinary(vcsdict[key]['binary'])
          PREcho 'Current directory looks like a ' . vcsdict[key] . ' repository but ' . vcsdist[key]['binary'] . ' command was not found on path.'
          let &shortmess = s:save_shortmess
          augroup! patchreview_plugin
          return
        else
          let s:the_diff_cmd = vcsdict[key]['binary'] . ' ' . vcsdict[key]['diffargs']
          let strip = vcsdict[key]['strip']

          PREcho 'Using [' . s:the_diff_cmd . '] to generate diffs for this ' . key . ' review.'
          let l:vcs = vcsdict[key]['binary']
          break
        endif
      else
        continue
      endif
    endfor
  else
    let s:the_diff_cmd = g:patchreview_diffcmd
    let strip = 0
  endif
  if ! exists('s:the_diff_cmd')
    PREcho 'Please define g:patchreview_diffcmd and make sure you are in a VCS controlled top directory.'
    let &shortmess = s:save_shortmess
    augroup! patchreview_plugin
    return
  endif

  try
    let l:outfile = tempname()
    let l:cmd = s:the_diff_cmd . ' > "' . l:outfile . '"'
    let v:errmsg = ''
    let l:cout = system(l:cmd)
    if v:errmsg == '' && exists('l:vcs') && l:vcs == 'cvs' && v:shell_error == 1
      " Ignoring CVS non-error
    elseif v:errmsg != '' || v:shell_error
      PREcho v:errmsg
      PREcho 'Could not execute [' . s:the_diff_cmd . ']'
      PREcho 'Error code: ' . v:shell_error
      PREcho l:cout
      PREcho 'Diff review aborted.'
      return
    endif
    let s:reviewmode = 'diff'
    call s:_GenericReview([l:outfile, strip])
  finally
    call delete(l:outfile)
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

"}}}

" modeline
" vim: set et fdl=1 fdm=marker fenc=latin ff=unix ft=vim sw=2 sts=0 ts=2 textwidth=78 nowrap :
