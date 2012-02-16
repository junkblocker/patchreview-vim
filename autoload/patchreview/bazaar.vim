let s:PRemote = {}
let s:bazaar = {}

function! s:bazaar.Detect() " {{{
  return isdirectory('.bzr')
endfunction
" }}}

function! s:bazaar.GetDiff() " {{{
  let l:diff = s:PRemote.GenDiff('bzr diff')
  return {'strip': 0, 'diff': l:diff}
endfunction
" }}}

function! patchreview#bazaar#register(remote) "{{{
  let s:PRemote = a:remote
  return s:bazaar
endfunction
" }}}

" vim: set et fdl=99 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :

