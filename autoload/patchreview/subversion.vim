" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2016 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
" Initialization {{{
let s:driver = {}
let s:subversion = {}
" }}}
function! s:subversion.detect() " {{{
  return isdirectory('.svn')
endfunction
" }}}
function! s:subversion.get_diff() " {{{
  let l:diff = s:driver.generate_diff('svn diff')
  return {'strip': 0, 'diff': l:diff}
endfunction
" }}}
function! patchreview#subversion#register(remote) "{{{
  let s:driver = a:remote
  return s:subversion
endfunction
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
"}}}
