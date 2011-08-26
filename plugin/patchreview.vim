" VIM plugin for doing single, multi-patch or diff code reviews {{{
" Home:  http://www.vim.org/scripts/script.php?script_id=1563

" Version       : 0.3.2                                      "{{{
" Author        : Manpreet Singh < junkblocker@yahoo.com >
" Copyright     : 2006-2011 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"
" Changelog :
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
"   0.2 - Removed the need for filterdiff by implemeting it in pure vim script
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
" 1) If a .sw? is present or file is open in another instance, vim pauses for
"    it. Maybe use SwapExists.
" 2) git staged support?
" 3) See if Windows line endings have an issue.
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
"   3) Optional (but recommended for speed)
"
"      Install patchutils ( http://cyberelk.net/tim/patchutils/ ) for your
"      OS. For windows it is availble from Cygwin
"
"         http://www.cygwin.com
"
"      or GnuWin32
"
"         http://gnuwin32.sourceforge.net/
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
"  Optionally, specify the locations to these filterdiff and patch commands
"  and location of a temporary directory to use in your .vimrc.
"
"      let g:patchreview_patch       = '/path/to/gnu/patch'
"
"      " If you are using filterdiff
"      let g:patchreview_filterdiff  = '/path/to/filterdiff'
"
"
" Usage:
"
"  Please see :help patchreview or :help diffreview for details.
"
""}}}

" Enabled only during development
" unlet! g:loaded_patchreview " DEBUG
" unlet! g:patchreview_patch " DEBUG
" unlet! g:patchreview_filterdiff " DEBUG
" let g:patchreview_patch = 'patch'    " DEBUG

" load only once
if &cp || (! exists('g:patchreview_debug') && exists('g:loaded_patchreview'))
  finish
endif
if v:version < 700
  echomsg 'patchreview: You need at least Vim 7.0'
  finish
endif
if ! has('diff')
  call confirm('patchreview.vim plugin needs (G)VIM built with +diff support to work.')
  finish
endif

let g:loaded_patchreview="0.3.2"

let s:msgbufname = '-PatchReviewMessages-'

function! <SID>Debug(str)                                                 "{{{
  if exists('g:patchreview_debug')
    Pecho 'DEBUG: ' . a:str
  endif
endfunction
command! -nargs=+ -complete=expression Debug call s:Debug(<args>)
"}}}

function! <SID>PR_wipeMsgBuf()                                            "{{{
  let winnum = bufwinnr(s:msgbufname)
  if winnum != -1 " If the window is already open, jump to it
    let cur_winnr = winnr()
    if winnr() != winnum
      exe winnum . 'wincmd w'
      bw
      exe cur_winnr . 'wincmd w'
    endif
  endif
endfunction
"}}}

function! <SID>Pecho(...)                                                 "{{{
  " Usage: Pecho(msg, [return_to_original_window_flag])
  "            default return_to_original_window_flag = 0
  "
  let l:curtabnr = tabpagenr()
  if exists('s:msgbuftabnr')
    exe ':tabnext ' . s:msgbuftabnr
  else
    let s:msgbuftabnr = tabpagenr()
  endif
  let cur_winnr = winnr()
  let winnum = bufwinnr(s:msgbufname)
  if winnum != -1 " If the window is already open, jump to it
    if winnr() != winnum
      exe winnum . 'wincmd w'
    endif
  else
    let bufnum = bufnr(s:msgbufname)
    let wcmd = bufnum == -1 ? s:msgbufname : '+buffer' . bufnum
    exe 'silent! botright 5split ' . wcmd
  endif
  setlocal modifiable
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal noswapfile
  setlocal nowrap
  setlocal nobuflisted
  if a:0 != 0
    silent! $put =a:1
  endif
  exe ':$'
  setlocal nomodifiable
  exe ':tabnext ' . l:curtabnr
  if a:0 > 1 && a:2
    exe cur_winnr . 'wincmd w'
  endif
endfunction

command! -nargs=+ -complete=expression Pecho call s:Pecho(<args>)
"}}}

function! <SID>PR_checkBinary(BinaryName)                                 "{{{
  " Verify that BinaryName is specified or available
  if ! exists('g:patchreview_' . a:BinaryName)
    if executable(a:BinaryName)
      let g:patchreview_{a:BinaryName} = a:BinaryName
      return 1
    else
      Pecho 'g:patchreview_' . a:BinaryName . ' is not defined and ' . a:BinaryName . ' command could not be found on path.'
      Pecho 'Please define it in your .vimrc.'
      return 0
    endif
  elseif ! executable(g:patchreview_{a:BinaryName})
    Pecho 'Specified g:patchreview_' . a:BinaryName . ' [' . g:patchreview_{a:BinaryName} . '] is not executable.'
    return 0
  else
    return 1
  endif
endfunction
"}}}

function! <SID>ExtractDiffsNative(...)                                    "{{{
  " Sets g:patches = {'reason':'', 'patch':[
  " {
  "  'filename': filepath
  "  'type'    : '+' | '-' | '!'
  "  'content' : patch text for this file
  " },
  " ...
  " ]}
  let g:patches = {'reason' : '', 'patch' : []}
  " TODO : User pointers into lines list rather then use collect
  if a:0 == 0
    let g:patches['reason'] = "ExtractDiffsNative expects at least a patchfile argument"
    return
  endif
  let patchfile = expand(a:1, ':p')
  if a:0 > 1
    let patch = a:2
  endif
  if ! filereadable(patchfile)
    let g:patches['reason'] = "File " . patchfile . " is not readable"
    return
  endif
  unlet! filterdiffcmd
  let filterdiffcmd = '' . g:patchreview_filterdiff . ' --list -s ' . patchfile
  let fileslist = split(system(filterdiffcmd), '[\r\n]')
  for filewithchangetype in fileslist
    if filewithchangetype !~ '^[!+-] '
      Pecho '*** Skipping review generation due to unknown change for [' . filewithchangetype . ']'
      continue
    endif

    unlet! this_patch
    let this_patch = {}

    unlet! relpath
    let relpath = substitute(filewithchangetype, '^. ', '', '')

    let this_patch['filename'] = relpath

    if filewithchangetype =~ '^! '
      let this_patch['type'] = '!'
    elseif filewithchangetype =~ '^+ '
      let this_patch['type'] = '+'
    elseif filewithchangetype =~ '^- '
      let this_patch['type'] = '-'
    endif

    unlet! filterdiffcmd
    let filterdiffcmd = '' . g:patchreview_filterdiff . ' -i ' . relpath . ' ' . patchfile
    let this_patch['content'] = split(system(filterdiffcmd), '\n')
    let g:patches['patch'] += [this_patch]
    Debug "Patch collected for " . relpath
  endfor
endfunction
"}}}

function! <SID>ExtractDiffsPureVim(...)                                   "{{{
  " Sets g:patches = {'reason':'', 'patch':[
  " {
  "  'filename': filepath
  "  'type'    : '+' | '-' | '!'
  "  'content' : patch text for this file
  " },
  " ...
  " ]}
  let g:patches = {'reason' : '', 'patch' : []}
  " TODO : User pointers into lines list rather then use collect
  if a:0 == 0
    let g:patches['reason'] = "ExtractDiffsPureVim expects at least a patchfile argument"
    return
  endif
  let patchfile = expand(a:1, ':p')
  if a:0 > 1
    let patch = a:2
  endif
  if ! filereadable(patchfile)
    let g:patches['reason'] = "File " . patchfile . " is not readable"
    return
  endif
  let collect = []
  let line_num = 0
  let lines = readfile(patchfile, "b")
  let linescount = len(lines)
  State 'START'
  while line_num < linescount
    let line = lines[line_num]
    Debug 'Read: [' . line . ']'
    let line_num += 1
    if State() == 'START' " {{{
      let mat = matchlist(line, '^--- \([^\t]\+\).*$')
      if ! empty(mat) && mat[1] != ''
        State 'MAYBE_UNIFIED_DIFF'
        let p_first_file = mat[1]
        let collect = [line]
        continue
      endif
      let mat = matchlist(line, '^\*\*\* \([^\t]\+\).*$')
      if ! empty(mat) && mat[1] != ''
        State 'MAYBE_CONTEXT_DIFF'
        let p_first_file = mat[1]
        let collect = [line]
        continue
      endif
      continue
      " }}}
    elseif State() == 'MAYBE_CONTEXT_DIFF' " {{{
      let mat = matchlist(line, '^--- \([^\t]\+\).*$')
      if empty(mat) || mat[1] == ''
        State 'START'
        let line_num -= 1
        Debug 'Back to square one ' . line()
        continue
      endif
      let p_second_file = mat[1]
      if p_first_file == '/dev/null'
        if p_second_file == '/dev/null'
          let g:patches['reason'] = "Malformed diff found at line " . line_num
          return
        endif
        let p_type = '+'
        let filepath = p_second_file
      else
        if p_second_file == '/dev/null'
          let p_type = '-'
          let filepath = p_first_file
        else
          let p_type = '!'
          let filepath = p_second_file
        endif
      endif
      State 'EXPECT_15_STARS'
      let collect += [line]
      " }}}
    elseif State() == 'EXPECT_15_STARS' " {{{
      if line !~ '^*\{15}$'
        State 'START'
        let line_num -= 1
        continue
      endif
      State 'EXPECT_CONTEXT_CHUNK_HEADER_1'
      let collect += [line]
      " }}}
    elseif State() == 'EXPECT_CONTEXT_CHUNK_HEADER_1' " {{{
      let mat = matchlist(line, '^\*\*\* \(\d\+,\)\?\(\d\+\) \*\*\*\*$')
      if empty(mat) || mat[1] == ''
        State 'START'
        let line_num -= 1
        continue
      endif
      let collect += [line]
      State 'SKIP_CONTEXT_STUFF_1'
      continue
      " }}}
    elseif State() == 'SKIP_CONTEXT_STUFF_1' " {{{
      if line !~ '^[ !+].*$'
        let mat = matchlist(line, '^--- \(\d\+\),\(\d\+\) ----$')
        if ! empty(mat) && mat[1] != '' && mat[2] != ''
          let goal_count = mat[2] - mat[1] + 1
          let c_count = 0
          State 'READ_CONTEXT_CHUNK'
          let collect += [line]
          Debug " Goal count set to " . goal_count
          continue
        endif
        State 'START'
        let line_num -= 1
        continue
      endif
      let collect += [line]
      continue
      " }}}
    elseif State() == 'READ_CONTEXT_CHUNK' " {{{
      let c_count += 1
      if c_count == goal_count
        let collect += [line]
        State 'BACKSLASH_OR_CRANGE_EOF'
        continue
      else " goal not met yet
        let mat = matchlist(line, '^\([\\!+ ]\).*$')
        if empty(mat) || mat[1] == ''
          let line_num -= 1
          State 'START'
          continue
        endif
        let collect += [line]
        continue
      endif
      " }}}
    elseif State() == 'BACKSLASH_OR_CRANGE_EOF' " {{{
      if line =~ '^\\ No newline.*$'   " XXX: Can we go to another chunk from here??
        let collect += [line]
        let this_patch = {}
        let this_patch['filename'] = filepath
        let this_patch['type'] = p_type
        let this_patch['content'] = collect
        let g:patches['patch'] += [this_patch]
        Debug "Patch collected for " . filepath
        State 'START'
        continue
      endif
      if line =~ '^\*\{15}$'
        let collect += [line]
        State 'EXPECT_CONTEXT_CHUNK_HEADER_1'
        continue
      endif
      let this_patch = {'filename': filepath, 'type':  p_type, 'content':  collect}
      let g:patches['patch'] += [this_patch]
      let line_num -= 1
      State 'START'
      Debug "Patch collected for " . filepath
      continue
      " }}}
    elseif State() == 'MAYBE_UNIFIED_DIFF' " {{{
      let mat = matchlist(line, '^+++ \([^\t]\+\).*$')
      if empty(mat) || mat[1] == ''
        State 'START'
        let line_num -= 1
        continue
      endif
      let p_second_file = mat[1]
      if p_first_file == '/dev/null'
        if p_second_file == '/dev/null'
          let g:patches['reason'] = "Malformed diff found at line " . line_num
          return
        endif
        let p_type = '+'
        let filepath = p_second_file
      else
        if p_second_file == '/dev/null'
          let p_type = '-'
          let filepath = p_first_file
        else
          let p_type = '!'
          let filepath = p_second_file
        endif
      endif
      State 'EXPECT_UNIFIED_RANGE_CHUNK'
      let collect += [line]
      continue
      " }}}
    elseif State() == 'EXPECT_UNIFIED_RANGE_CHUNK' "{{{
      let mat = matchlist(line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
      if ! empty(mat)
        let old_goal_count = mat[2]
        let new_goal_count = mat[4]
        let o_count = 0
        let n_count = 0
        Debug "Goal count set to " . old_goal_count . ', ' . new_goal_count
        State 'READ_UNIFIED_CHUNK'
        let collect += [line]
      else
        let this_patch = {'filename': filepath, 'type': p_type, 'content': collect}
        let g:patches['patch'] += [this_patch]
        Debug "Patch collected for " . filepath
        State 'START'
        let line_num -= 1
      endif
      continue
      "}}}
    elseif State() == 'READ_UNIFIED_CHUNK' " {{{
      if o_count == old_goal_count && n_count == new_goal_count
        if line =~ '^\\.*$'   " XXX: Can we go to another chunk from here??
          let collect += [line]
          let this_patch = {'filename': filepath, 'type': p_type, 'content': collect}
          let g:patches['patch'] += [this_patch]
          Debug "Patch collected for " . filepath
          State 'START'
          continue
        endif
        let mat = matchlist(line, '^@@ -\(\d\+,\)\?\(\d\+\) +\(\d\+,\)\?\(\d\+\) @@.*$')
        if ! empty(mat)
          let old_goal_count = mat[2]
          let new_goal_count = mat[4]
          let o_count = 0
          let n_count = 0
          Debug "Goal count set to " . old_goal_count . ', ' . new_goal_count
          let collect += [line]
          continue
        endif
        let this_patch = {'filename': filepath, 'type': p_type, 'content': collect}
        let g:patches['patch'] += [this_patch]
        Debug "Patch collected for " . filepath
        let line_num -= 1
        State 'START'
        continue
      else " goal not met yet
        let mat = matchlist(line, '^\([\\+ -]\).*$')
        if empty(mat) || mat[1] == ''
          let line_num -= 1
          State 'START'
          continue
        endif
        let chr = mat[1]
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
        let collect += [line]
        continue
      endif
      " }}}
    else " {{{
      let g:patches['reason'] = "Internal error: Do not use the plugin anymore and if possible please send the diff or patch file you tried it with to Manpreet Singh <junkblocker@yahoo.com>"
      return
    endif " }}}
  endwhile
  "Pecho State()
  if (State() == 'READ_CONTEXT_CHUNK' && c_count == goal_count) || (State() == 'READ_UNIFIED_CHUNK' && n_count == new_goal_count && o_count == old_goal_count)
    let this_patch = {'filename': filepath, 'type': p_type, 'content': collect}
    let g:patches['patch'] += [this_patch]
    Debug "Patch collected for " . filepath
  endif
  return
endfunction
"}}}

function! State(...)  " For easy manipulation of diff extraction state      "{{{
  if a:0 != 0
    let s:STATE = a:1
    Debug s:STATE
  else
    if ! exists('s:STATE')
      let s:STATE = 'START'
      Debug s:STATE
    endif
    return s:STATE
  endif
endfunction
com! -nargs=+ -complete=expression State call State(<args>)
"}}}

function! <SID>PatchReview(...)                                           "{{{
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o'
  augroup end
  let s:save_shortmess = &shortmess
  let s:save_aw = &autowrite
  let s:save_awa = &autowriteall
  set shortmess=aW
  call s:PR_wipeMsgBuf()
  let s:reviewmode = 'patch'
  call s:_GenericReview(a:000)
  let &autowriteall = s:save_awa
  let &autowrite = s:save_aw
  let &shortmess = s:save_shortmess
  augroup! patchreview_plugin
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
    Pecho 'This plugin needs VIM 7 or higher'
    return
  endif

  " +diff required
  if ! has('diff')
    Pecho 'This plugin needs VIM built with +diff feature.'
    return
  endif


  if s:reviewmode == 'diff'
    let patch_R_option = ' -t -R '
  elseif s:reviewmode == 'patch'
    let patch_R_option = ''
  else
    Pecho 'Fatal internal error in patchreview.vim plugin'
    return
  endif

  " Check passed arguments
  if len(a:argslist) == 0
    Pecho 'PatchReview command needs at least one argument specifying a patchfile path.'
    return
  endif
  let StripCount = 0
  if len(a:argslist) >= 1 && ((s:reviewmode == 'patch' && len(a:argslist) <= 3) || (s:reviewmode == 'diff' && len(a:argslist) == 2))
    let PatchFilePath = expand(a:argslist[0], ':p')
    if ! filereadable(PatchFilePath)
      Pecho 'File [' . PatchFilePath . '] is not accessible.'
      return
    endif
    if len(a:argslist) >= 2 && s:reviewmode == 'patch'
      let s:SrcDirectory = expand(a:argslist[1], ':p')
      if ! isdirectory(s:SrcDirectory)
        Pecho '[' . s:SrcDirectory . '] is not a directory'
        return
      endif
      try
        " Command line has already escaped the path
        exe 'cd ' . s:SrcDirectory
      catch /^.*E344.*/
        Pecho 'Could not change to directory [' . s:SrcDirectory . ']'
        return
      endtry
    endif
    if s:reviewmode == 'diff'
      " passed in by default
      let StripCount = eval(a:argslist[1])
    elseif s:reviewmode == 'patch'
      let StripCount = 1
      " optional strip count
      if len(a:argslist) == 3
        let StripCount = eval(a:argslist[2])
      endif
    endif
  else
    if s:reviewmode == 'patch'
      Pecho 'PatchReview command needs at most three arguments: patchfile path, optional source directory path and optional strip count.'
    elseif s:reviewmode == 'diff'
      Pecho 'DiffReview command accepts no arguments.'
    endif
    return
  endif

  " Verify that patch command and temporary directory are available or specified
  if ! s:PR_checkBinary('patch')
    return
  endif

  " Requirements met, now execute
  let PatchFilePath = fnamemodify(PatchFilePath, ':p')
  if s:reviewmode == 'patch'
    Pecho 'Patch file      : ' . PatchFilePath
  endif
  Pecho 'Source directory: ' . getcwd()
  Pecho '------------------'
  if s:PR_checkBinary('filterdiff')
    Debug "Using filterdiff"
    call s:ExtractDiffsNative(PatchFilePath)
  else
    Debug "Using own diff extraction (slower)"
    call s:ExtractDiffsPureVim(PatchFilePath)
  endif
  for patch in g:patches['patch']
    if patch.type !~ '^[!+-]$'
      Pecho '*** Skipping review generation due to unknown change [' . patch.type . ']', 1
      continue
    endif
    unlet! relpath
    let relpath = patch.filename
    " XXX: svn diff and hg diff produce different kind of outputs, one requires
    " XXX: stripping but the other doesn't. We need to take care of that
    let stripmore = StripCount
    let StrippedRelativeFilePath = relpath
    while stripmore > 0
      " strip one
      let StrippedRelativeFilePath = substitute(StrippedRelativeFilePath, '^[^\\\/]\+[^\\\/]*[\\\/]' , '' , '')
      let stripmore -= 1
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
    let bufnum = bufnr(relpath)
    if buflisted(bufnum) && getbufvar(bufnum, '&mod')
      Pecho 'Old buffer for file [' . relpath . '] exists in modified state. Skipping review.', 1
      continue
    endif
    let tmpname = tempname()

    try
      " write patch for patch.filename into tmpname
      call writefile(patch.content, tmpname)
      if patch.type == '+' && s:reviewmode == 'patch'
        Debug 'Case 1'
        let inputfile = ''
        let patchcmd = '!' . g:patchreview_patch . patch_R_option . ' -s -o "' . tmpname . '.file" "' . inputfile . '" < "' . tmpname . '"'
      elseif patch.type == '+' && s:reviewmode == 'diff'
        Debug 'Case 2'
        let inputfile = ''
        unlet! patchcmd
      else
        Debug 'Case 3'
        let inputfile = expand(StrippedRelativeFilePath, ':p')
        let patchcmd = '!' . g:patchreview_patch . patch_R_option . ' -s -o "' . tmpname . '.file" "' . inputfile . '" < "' . tmpname . '"'
      endif
      let error = 0
      if exists('patchcmd')
        let v:errmsg = ''
        Debug patchcmd
        silent exe patchcmd
        if v:errmsg != '' || v:shell_error
          let error = 1
          Pecho 'ERROR: Could not execute patch command.'
          Pecho 'ERROR:     ' . patchcmd
          Pecho 'ERROR: ' . v:errmsg
          Pecho 'ERROR: Diff skipped.'
        endif
      endif
      let s:origtabpagenr = tabpagenr()
      silent! exe 'tabedit ' . StrippedRelativeFilePath
      if ! error
        if exists('patchcmd')
          " modelines in loaded files mess with diff comparision
          let s:keep_modeline=&modeline
          let &modeline=0
          silent! exe 'vert diffsplit ' . tmpname . '.file'
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
        if ! filereadable(inputfile)
          Pecho 'ERROR: Original file ' . inputfile . ' does not exist.'
        endif
      endif
      if filereadable(tmpname . '.file.rej')
        silent! exe 'topleft 5split ' . tmpname . '.file.rej'
        Pecho msgtype . '*** REJECTED *** ' . relpath, 1
      else
        Pecho msgtype . ' ' . relpath, 1
      endif
    finally
      silent! exe 'tabn ' . s:origtabpagenr
      call delete(tmpname)
      call delete(tmpname . 'file')
      call delete(tmpname . 'file.rej')
    endtry
  endfor
  Pecho '-----'
  Pecho 'Done.', 1

endfunction
"}}}

function! <SID>DiffReview(...)                                            "{{{
  augroup patchreview_plugin
    autocmd!

    " When opening files which may be open elsewhere, open them in read only
    " mode
    au SwapExists * :let v:swapchoice='o'
  augroup end

  let s:save_shortmess = &shortmess
  set shortmess=aW
  call s:PR_wipeMsgBuf()

  let vcsdict = {
                  \'Mercurial'  : {'dir': '.hg',  'binary': 'hg',  'strip': 1, 'diffargs': 'diff'                  },
                  \'Bazaar-NG'  : {'dir': '.bzr', 'binary': 'bzr', 'strip': 0, 'diffargs': 'diff'                  },
                  \'monotone'   : {'dir': '_MTN', 'binary': 'mtn', 'strip': 0, 'diffargs': 'diff --unified'        },
                  \'Subversion' : {'dir': '.svn', 'binary': 'svn', 'strip': 0, 'diffargs': 'diff'                  },
                  \'cvs'        : {'dir': 'CVS',  'binary': 'cvs', 'strip': 0, 'diffargs': '-q diff -u'            },
                  \'git'        : {'dir': '.git', 'binary': 'git', 'strip': 1, 'diffargs': 'diff -p -U5 --no-color'},
                  \}

  unlet! s:theDiffCmd
  unlet! l:vcs
  if ! exists('g:patchreview_diffcmd')
    for key in keys(vcsdict)
      if isdirectory(vcsdict[key]['dir'])
        if ! s:PR_checkBinary(vcsdict[key]['binary'])
          Pecho 'Current directory looks like a ' . vcsdict[key] . ' repository but ' . vcsdist[key]['binary'] . ' command was not found on path.'
          let &shortmess = s:save_shortmess
          augroup! patchreview_plugin
          return
        else
          let s:theDiffCmd = vcsdict[key]['binary'] . ' ' . vcsdict[key]['diffargs']
          let strip = vcsdict[key]['strip']

          Pecho 'Using [' . s:theDiffCmd . '] to generate diffs for this ' . key . ' review.'
          let l:vcs = vcsdict[key]['binary']
          break
        endif
      else
        continue
      endif
    endfor
  else
    let s:theDiffCmd = g:patchreview_diffcmd
    let strip = 0
  endif
  if ! exists('s:theDiffCmd')
    Pecho 'Please define g:patchreview_diffcmd and make sure you are in a VCS controlled top directory.'
    let &shortmess = s:save_shortmess
    augroup! patchreview_plugin
    return
  endif

  try
    let outfile = tempname()
    let cmd = s:theDiffCmd . ' > "' . outfile . '"'
    let v:errmsg = ''
    let cout = system(cmd)
    if v:errmsg == '' && exists('l:vcs') && l:vcs == 'cvs' && v:shell_error == 1
      " Ignoring CVS non-error
    elseif v:errmsg != '' || v:shell_error
      Pecho v:errmsg
      Pecho 'Could not execute [' . s:theDiffCmd . ']'
      Pecho 'Error code: ' . v:shell_error
      Pecho cout
      Pecho 'Diff review aborted.'
      let &shortmess = s:save_shortmess
      augroup! patchreview_plugin
      return
    endif
    let s:reviewmode = 'diff'
    call s:_GenericReview([outfile, strip])
    let &shortmess = s:save_shortmess
    augroup! patchreview_plugin
  finally
    call delete(outfile)
  endtry
endfunction
"}}}

" End user commands                                                         "{{{
"============================================================================
" :PatchReview
command! -nargs=* -complete=file PatchReview call s:PatchReview (<f-args>)

" :DiffReview
command! -nargs=0 DiffReview call s:DiffReview()
"}}}

" Development                                                               "{{{
if exists('g:patchreview_debug')
  " Tests
  function! <SID>PRExtractTestNative(...)
    "let patchfiles = glob(expand(a:1) . '/?*')
    "for fname in split(patchfiles)
    call s:PR_wipeMsgBuf()
    let fname = a:1
    call s:ExtractDiffsNative(fname)
    for patch in g:patches['patch']
      for line in patch.content
        Pecho line
      endfor
    endfor
    "endfor
  endfunction

  function! <SID>PRExtractTestVim(...)
    "let patchfiles = glob(expand(a:1) . '/?*')
    "for fname in split(patchfiles)
    call s:PR_wipeMsgBuf()
    let fname = a:1
    call s:ExtractDiffsPureVim(fname)
    for patch in g:patches['patch']
      for line in patch.content
        Pecho line
      endfor
    endfor
    "endfor
  endfunction

  command! -nargs=+ -complete=file PRTestVim call s:PRExtractTestVim(<f-args>)
  command! -nargs=+ -complete=file PRTestNative call s:PRExtractTestNative(<f-args>)
endif
"}}}

" modeline
" vim: set et fdl=1 fdm=marker fenc=latin ff=unix ft=vim sw=2 sts=0 ts=2 textwidth=78 nowrap :
