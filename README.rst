===============
patchreview.vim
===============

.. contents::
   :depth: 5
   :backlinks: top

Introduction
============

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
bazaar, hg, bzr, cvs, monotone, mtn, git, perforce, fossil)


Requirements
============

1. Vim 7.0 or higher built with ``+diff`` option.

2. A gnu compatible patch command installed. This is the standard patch command
   on any Linux, Mac OS X, \*BSD, Cygwin or ``/usr/bin/gpatch`` on newer
   Solaris/OpenSolairs.

   For Windows, UnxUtils ( http://unxutils.sourceforge.net/ ) provides a
   compatible patch implementation. However, you might need to set:

   .. code:: vim

      let g:patchreview_patch_needs_crlf = 1

   in your .vimrc file.


Installation
============

Option 1: Use a bundle manager
------------------------------

Use your favorite vim package manager to install from the github repository for
the project. Examples:

.. code:: vim

   " With vim-plug
   Plug 'junkblocker/patchreview-vim'

   " With NeoBundle
   NeoBundle 'junkblocker/patchreview-vim'

   " With dein.vim
   call dein#add('junkblocker/patchreview-vim')

   " With Vundle  
   Bundle 'junkblocker/patchreview-vim'


Option 2: Installation with Pathogen
------------------------------------

.. code:: sh

   % cd ~/.vim/bundle
   % git clone https://github.com/junkblocker/patchreview-vim


Option 3: Install by hand
-------------------------

1) Extract the zip from http://www.vim.org/scripts/script.php?script_id=1563
   in your ``$HOME/.vim`` or ``$VIM/vimfiles`` directory and restart vim. The
   directory location relevant to your platform can be seen by running:

   .. code:: vim

      :help add-global-plugin

   in vim.

   Alternatively, if installing from extracted form, copy the directories by
   hand:

   .. code:: sh

      % cp -r autoload doc plugin $HOME/.vim/

2) Generate help tags to use help

   .. code:: vim

      :helptags $HOME/.vim/doc

   or, for example on Windows if you installed under ``$VIM/vimfiles``:

   .. code:: vim

      :helptags $VIM/vimfiles/doc

   etc.


Usage
=====

* Reviewing current changes in your workspace:

  .. code:: vim

     :DiffReview

* Reviewing staged git changes:

  .. code:: vim

     :DiffReview git staged --no-color -U5

* Reviewing a patch:

  .. code:: vim

     :PatchReview some.patch

* Reviewing a previously applied patch (AKA reverse patch review):

  .. code:: vim

     :ReversePatchReview some.patch

* See

  .. code:: vim

     :h patchreview

  for usage details.


Limitations
===========

The plugin can not handle diffs/patches which change the line ending types between DOS, UNIX and Mac etc.
This is a general patching problem and is not specific to this plugin.


Fork me
=======

Fork this project at https://github.com/junkblocker/patchreview-vim
