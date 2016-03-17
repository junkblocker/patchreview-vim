" Some simple tests suited to my setup.
set nocompatible

" Uses thinca/vim-prettyprint to dump information if available.
function! s:dump(something)
  if exists(":PP")
    echomsg PP(a:something)
  endif
endfunction

unlet! s:mess
redir => s:mess
try
  exe 'set runtimepath=' . expand("%:p:h")
  for names in ['bundles', 'bundle']
    let s:bpath = expand("~/.vim/bundle/prettyprint")
    if isdirectory(s:bpath)
      exe 'set runtimepath+=' . s:bpath
    endif
  endfor

  set verbose=1
  runtime plugin/patchreview.vim
  runtime plugin/prettyprint.vim
  set verbose=0

  """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  " argument checking is not broken
  """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  try
    PatchReview
    echomsg 'Arguments check failed.'
  catch /^Vim:E471:\s*Argument required:\s*PatchReview/
    echomsg 'Arguments check passed.'
  catch /.*/
    echomsg 'Arguments check failed. Unexpected error: ' . v:exception
  endtry

  """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  " Check patch parsing is not broken
  """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  function! s:test_parse(patchfile, expected_parse)
    unlet! g:patches
    let l:patchlines = patchreview#get_patchfile_lines(a:patchfile)
    call patchreview#extract_diffs(l:patchlines, 0)
    if g:patches !=#  a:expected_parse
      echomsg "Parsing" a:patchfile "failed."
      echomsg "Expected:"
      call s:dump(a:expected_parse)
      echomsg "Actual:"
      call s:dump(g:patches)
    else
      echomsg "Parsing" a:patchfile "succeeded."
    endif
  endfunction

  call s:test_parse('test/test1.patch', {
        \ 'fail': '',
        \ 'patch': [
        \ {
        \ 'content': [
        \ '--- a/x',
        \ '+++ b/x',
        \ '@@ -1,7 +1,7 @@',
        \ ' foo',
        \ ' bar',
        \ ' ',
        \ '-fubar',
        \ '+foobar',
        \ ' baz',
        \ ' quux',
        \ ' hoge',
        \ '@@ -9,6 +9,9 @@',
        \ ' a',
        \ ' b',
        \ ' c',
        \ '+d',
        \ '+e',
        \ '+f',
        \ ' g',
        \ ' h',
        \ ' i'
        \ ],
        \ 'filename': 'a/x',
        \ 'type': '!'
        \ }
        \ ]
        \ })

  call s:test_parse('test/test2.patch', {
        \ 'fail': '',
        \ 'patch': [
        \   {
        \     'content': [
        \       '*** ../a/b	2013-06-29 13:22:22.000000000 +0800',
        \       '--- a/b	2013-10-12 20:22:22.000000000 +0800',
        \       '***************',
        \       '*** 1,4 ****',
        \       '! " stuff.',
        \       '  ',
        \       '  foo',
        \       '  bar',
        \       '--- 1,4 ----',
        \       '! other stuff',
        \       '  ',
        \       '  foo',
        \       '  bar'
        \     ],
        \     'filename': 'a/b',
        \     'type': '!'
        \   },
        \   {
        \     'content': [
        \       '*** ../k/x/y	2013-00-01 12:36:90.000000000 +0800',
        \       '--- x/y	2013-00-02 00:13:04.000000000 +0100',
        \       '***************',
        \       '*** 740,741 ****',
        \       '--- 740,743 ----',
        \       '  {   /* Add new patch number below this line */',
        \       '+ /**/',
        \       '+     53,',
        \       '  /**/'
        \     ],
        \     'filename': 'x/y',
        \     'type': '!'
        \   }
        \ ]
        \ })

finally
  echomsg 'All done.'
  redir END
  $put =s:mess
  redraw!
  setlocal nomodified nomodifiable
endtry
" vim: set et fdm=manual fenc=utf-8 ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
