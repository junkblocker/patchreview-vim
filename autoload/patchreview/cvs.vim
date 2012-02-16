let s:PRemote = {}
let s:cvs = {}

function! s:cvs.Detect() " {{{
  return isdirectory('CVS')
endfunction
" }}}

function! s:cvs.GetDiff() " {{{
  return {'strip': 0, 'diff': s:PRemote.GenDiff('cvs diff -q -u')}
endfunction
" }}}

function! patchreview#cvs#register(remote) "{{{
  let s:PRemote = a:remote
  return s:cvs
endfunction
" }}}

" vim: set et fdl=99 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :

