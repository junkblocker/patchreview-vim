===============
patchreview.vim
===============

The Patch Review plugin allows easy single or multipatch code or diff reviews.

It opens each affected (modified/added/deleted) file in the patch or in a
version controlled workspace diff in a diff view in a separate tab.

VIM provides the ``:diffpatch`` command to do single file reviews but can not
handle patch files containing multiple patches as is common with software
development projects.  This plugin provides that missing functionality.

It also does not pollute the workspace like ``:diffpatch`` does by writing
files in the workspace.

It does automatic diff generation for various version control systems by
running their respective diff commands.

(Keywords: codereview, codereviews, code review, patch, patchutils, diff,
diffpatch, patchreview, patchreviews, patch review, vcs, scm, mercurial,
bazaar, hg, bzr, cvs, monotone, mtn, git, perforce)

QUICK INSTALL
=============

Unzip the files in your $HOME/.vim (or usually $HOME/vimfiles on Windows)
directory.

Or if installing from extracted form

1. Copy the directories to your ~/.vim/ directory::

   % cp -r autoload doc plugin ~/.vim/

2. Open Vim and do::

   :helptags ~/.vim/doc


REQUIREMENTS
============

1. Vim 7.0 or higher built with +diff option.

2. A gnu compatible patch command installed. This is the standard patch command
   on any Linux, Mac OS X, \*BSD, Cygwin or /usr/bin/gpatch on newer
   Solaris/OpenSolairs.

   For Windows, UnxUtils ( http://unxutils.sourceforge.net/ ) provides a
   compatible patch implementation. However, you might need to set::

         let g:patchreview_patch_needs_crlf = 1

   in your .vimrc file.

INSTALLING
==========

1) Extract the zip in your ``$HOME/.vim`` or ``$VIM/vimfiles`` directory and
   restart vim. The  directory location relevant to your platform can be seen
   by running::

      :help add-global-plugin

in vim.

Alternatively, if installing from extracted form, copy the directories by
hand::

      % cp -r autoload doc plugin ~/.vim/

2) Generate help tags to use help::

     :helptags $HOME/.vim/doc

  or::

     :helptags $VIM\vimfiles\doc

  etc.

USAGE
=====

See::

      :h patchreview

for usage.

Fork me
=======

Fork me at http://github.com/junkblocker/patchreview-vim
