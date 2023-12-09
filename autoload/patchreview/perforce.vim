" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2020 by Manpreet Singh
" Version       : 2.1.0
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
" Initialization {{{
let s:driver = {}
let s:perforce = {}
" }}}
function! s:perforce.detect() " {{{
  try
    let l:lines = split(system('p4 set'), '[\n\r]')
    let l:count = len(l:lines)
    let l:idx = 0
    let l:proofs_required = 2
    while l:idx < l:count
      let l:line = l:lines[l:idx]
      let l:idx += 1
      if l:line =~ '\(P4CLIENT\|P4PORT\)='
        let l:proofs_required -= 1
      endif
    endwhile
    return l:proofs_required == 0
  catch
    call s:driver.buflog('Exception ' . v:exception)
    call s:driver.buflog('From ' . v:throwpoint)
    return 0
  endtry
endfunction
" }}}
function! s:perforce.get_diff() " {{{
  " Excepted to return an array with diff lines in it
  let l:diff = []
  let l:lines = split(system('p4 opened'), '[\n\r]')
  let l:linescount = len(l:lines)
  let l:line_num = 0
  while l:line_num < l:linescount
    let l:line = l:lines[l:line_num]
    call s:driver.progress('Processing ' . l:line)
    let l:line_num += 1
    let l:fwhere = substitute(l:line, '\#.*', '', '')
    let l:fwhere = split(system('p4 where ' . shellescape(l:fwhere)), '[\n\r]')[0]
    let l:fwhere = substitute(l:fwhere, '^.\+ ', '', '')
    let l:fwhere = substitute(l:fwhere, expand(getcwd(), ':p') . '/', '', '')
    if l:line =~ '\(delete \(default \)\?change\) .*\(text\|unicode\|utf16\)'
      call s:driver.progress('Fetching original ' . l:fwhere)
      let l:diff += ['--- ' . l:fwhere]
      let l:diff += ['+++ /dev/null']
      let l:diffl = map(split(system('p4 print -q ' . shellescape(l:fwhere)), '[\n\r]'), '"-" . v:val')
      let l:diff += ['@@ -1,' . len(l:diffl) . ' +0,0 @@']
      let l:diff += l:diffl
      unlet! l:diffl
    elseif l:line =~ '\(\(add\|branch\) \(default \)\?change\) .*\(text\|unicode\|utf16\)'
      call s:driver.progress('Reading ' . l:fwhere)
      let l:diff += ['--- /dev/null']
      let l:diff += ['+++ ' . l:fwhere]
      let l:diffl = map(readfile(l:fwhere, "b"), '"+" . v:val')
      let l:diff += ['@@ -0,0 +1,' . len(l:diffl) . ' @@']
      let l:diff += l:diffl
      unlet! l:diffl
    elseif l:line =~ '\(\(edit\|integrate\) \(default \)\?change\) .*\(text\|unicode\|utf16\)'
      call s:driver.progress('Diffing ' . l:fwhere)
      let l:diff += ['--- ' . l:fwhere]
      let l:diff += ['+++ ' . l:fwhere]
      let l:diffl = split(system('p4 diff -du ' . shellescape(l:fwhere)), '[\n\r]')
      let l:diff += l:diffl[2:]
      unlet! l:diffl
    else
      "throw "Do not recognize/handle this p4 opened file mode: " . l:line
      let l:diff += ['Binary files ' . l:fwhere . ' and ' . l:fwhere . ' differ']
    endif
  endwhile
  return {'strip': 0, 'diff': l:diff}
endfunction
" }}}
function! patchreview#perforce#register(remote) "{{{
  let s:driver = a:remote
  return s:perforce
endfunction
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
"}}}
