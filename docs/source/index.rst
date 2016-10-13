Welcome to Aisu, a package manager for Howl! (こんにちは、アイス)
==================================================================

Aisu (アイス) is a package manager for the `Howl text editor <http://howl.io/>`_,
built on top of Git and Mercurial.

If you like Aisu, you can star it on
`GitHub <https://github.com/kirbyfan64/aisu>`_! Stars make me happy. :D

Installing Aisu
***************

Ironically enough, you can't use Aisu to install itself (yet!) like most package
managers. Instead, you have to do things the old-fashioned way::

  $ mkdir ~/.howl/bundles
  $ cd ~/.howl/bundles
  $ git clone https://github.com/kirbyfan64/aisu.git

The console
***********

Aisu is used within Howl. Whenever a command is referenced in these docs, you can
run it by using Alt+X (to open up the Howl command line) and then entering the
command name (e.g. ``aisu-query``).

Upon running a command, a new buffer will be opened up containing various prompts
pertaining to the command. This is called the Aisu *console*. It behaves a lot
like a terminal would...except it's inside of Howl! While packages are being
installed, for instance, you can go and continue working inside of Howl, doing
other things in other buffers.

Whenever Aisu asks for package paths or names, you can specify multiple ones by
separating them by spaces. For instance, when ``aisu-uninstall`` asks for a
package name, you can specify multiple ones like
``my-first-package my-second-package``.

Installing and querying for packages
************************************

Aisu was designed to be really easy to use. To query information about and
install different packages, you can use the ``aisu-query`` and ``aisu-install``
commands. They will both ask for the path/repo of the package to install. This
can be a path to a local Git/Mercurial repository (``/home/my_user/my_repo``) or
a URL (``https://github.com/my_user/my_repo.git``). In addition, for packages on
GitHub, you can just use ``username/repo``; ``my_user/my_repo`` is shorthand for
``https://github.com/my_user/my_repo.git``.

If you're using ``aisu-query``, Aisu will download the package to a temporary
folder and print information about it (like author and description).
``aisu-install`` will do the same thing, followed by a confirmation message
verifying that you want to install the package.

Just like mentioned above, you can install multiple packages by separating their
paths with spaces.

Updating packages
*****************

To update packages, you can just run ``aisu-update``. This will ask for the
packages to update. If you want to update all your packages, you can just enter
an asterisk (``*``). In addition, you can use Ctrl+Space to auto-complete with a
list of installed packages.

Uninstalling packages
*********************

``aisu-uninstall`` will uninstall any given packages. Just like ``aisu-update``,
you can press Ctrl+Space in order to auto-complete with a list of packages.

Creating packages
*****************

By default, Aisu looks for a file called ``aisu.moon``. It looks kind of like
this:

.. code-block:: moonscript

  {
    meta:
      author: 'Author name here'
      description: 'Description here'
      license: 'License here'
      version: 'Version here'
    build: (buffer) ->
      -- This function will be run whenever the package is installed/updated.
  }

Any of the fields can be ommited.

You can also use Lua with ``aisu.lua``, like this:

.. code-block:: lua

  return {
    meta = {
      author = 'Author name here',
      description = 'Description here',
      license = 'License here',
      version = 'Version here'
    },

    build = function (buffer)
      -- This function will be run whenever the package is installed/updated.
    end
  }

If neither ``aisu.moon`` nor ``aisu.lua`` is present, Aisu will attempt to
parse ``init.moon`` to find the metadata. If that also fails, then Aisu will
ask you if it can run ``init.moon`` or ``init.lua`` to get the metadata.
Failing that, it bails and assumes all the metadata is unknown.

The most interesting part here is the ``build`` function. It is passed the Aisu
ControlBuffer_ and is supposed to setup anything required for the package to
function correctly. An example is:

.. code-block:: moonscript

  build: (buffer, dir) ->
    -- Run make. dir is the directory holding the package.
    aisu.spawn_in_buffer buffer,
      cmd: {'make'}
      working_directory: dir

A full example of an ``aisu.moon`` can be seen in the ``howl-autoclang`` bundle:

.. code-block:: moonscript

  {
    -- Metadata
    meta:
      author: 'Ryan Gonzalez'
      description: 'Clang-based autocompletion for C/C++'
      license: 'MIT'
      version: '0.1'

    -- The build function: runs each command.
    build: (buf, dir) ->
      cmds = {
        {'git', 'submodule', 'init'}
        {'git', 'submodule', 'update'}
        {'make', '-C', 'ljclang', 'libljclang.so'}
      }
      for cmd in *cmds
        aisu.spawn_in_buffer buf,
          :cmd
          working_directory: dir
  }

Reducing duplication
^^^^^^^^^^^^^^^^^^^^

If you haven't noticed, ``aisu.moon`` 's ``meta`` field is largely the same as
``init.moon`` 's ``info``. Since that's a bit of a chore to maintain, you can
just do this in ``init.moon``:

.. code-block:: moonscript

  -- ... normal code here ...
  {
    -- The magic is here:
    info: bundle_load('aisu').meta
    -- ...
  }

This just loads up ``aisu.moon`` and grabs the ``meta`` field.

FAQ
***

Since Aisu is new, there haven't really been any questions asked yet, so this
mostly came off the top of my head. Which explains why it makes almost no
sense...

Does Aisu have dependency management?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Not yet. This isn't that high of a priority at the moment, since packages
designed for text editors (like Howl!) usually aren't as dependency-happy as
NodeJS packages (a.k.a. ``left-pad``).

Is Aisu self-updating?
^^^^^^^^^^^^^^^^^^^^^^

Again, not yet. Eventually, Aisu will be a valid package of its own, and you'll
just run a quick bootstrap script to install it.

Why the hell did you name this Aisu?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Aisu (アイス) is Japanese for ice. Wolves can live in cold weather. Howling is
what wolves do. Get it? Get it?

(To top it off, I didn't realize it at first, but the Sphinx theme I used for
these docs was made by Japanese people. Kind of a weird coincidence...)

API documentation
*****************

.. _core:

The core
^^^^^^^^

- *aisu.setup()*

  Initializes Aisu.

- *aisu.packages*

  A table of installed packages. Each value is a table containing two fields:
  ``path`` (the package location) and ``vcs`` (the version control that the
  package uses; either ``git`` or ``hg``).

- *aisu.save_packages()*

  Writes the package list to ``~/.howl/aisu.lua``.

- *aisu.yield()*

  Like ``coroutine.yield``, but discards the first return value. Useful for
  ``ControlBuffer.open_prompt``, since it also returns the buffer, which you
  probably already have if you were calling ``open_prompt``!

.. _utils:

Utilities
^^^^^^^^^

- *aisu.bind(f, ...)*

  Does a function partial with the given function and arguments. Google it.

- *aisu.upper(s)*

  Returns the given string with the first letter capitalized.

- *aisu.spawn_in_buffer(buf, args)*

  Creates a new instance of ``howl.io.Process`` with the given arguments and
  writes the process output to the buffer. Returns the completed process.

.. _VCS:

VCS utilities
^^^^^^^^^^^^^

- *aisu.Vcs*

  An abstract class representing a version control system. Subclasses of ``Vcs``
  have four methods:

  - ``exec(cmd, dir)`` - Execute the command inside of the given directory.
  - ``clone(url, dir)`` - Clones the URL into the given directory.
  - ``update(dir)`` - Updates the repository inside the given directory.
  - ``revid(dir)`` - Retrieves the latest commit hash from the repository.

- *aisu.Git*
- *aisu.Mercurial*

  Two subclasses of ``aisu.Vcs`` that implement the corresponding version
  control system support.

- *aisu.get_vcs(vcs)*

  Given one of ``'git'`` or ``'hg'``, return the corresponding version control
  class (NOT an instance).

- *aisu.vcs_info()*

  Returns a table containing two keys, ``git`` and ``hg``. If the value of the
  key is ``false``, then the corresponding version control program isn't
  present; otherwise, it was present.

- *aisu.read_url(url)*

  If the URL is actually the GitHub repository shorthand, it returns the
  expanded version (e.g. ``my_user/my_repo`` ->
  ``https://github.com/my_user/my_repo.git``). Otherwise, it just returns the
  original argument.

- *aisu.identify_repo(url)*

  Returns the version control class corresponding to the given URL. If the URL
  points to a Git repo, then the function returns ``aisu.Git``, and, if it's a
  Mercurial repo, ``aisu.Mercurial``. If neither, then ``nil`` is returned.

.. _ControlBuffer:

``ControlBuffer``
^^^^^^^^^^^^^^^^^

- *aisu.ControlBuffer.prompt_begins*

  If a prompt is currently open, this is the buffer offset at which the prompt
  begins. Otherwise, it is ``nil``.

- *aisu.ControlBuffer.write(text, flair)*

  Writes the given text to the buffer, highlighted using the given flair.

- *aisu.ControlBuffer.writeln(text, flair)*

  Same as ``write``, but appends a newline to *text*.

- *aisu.ControlBuffer.info(text)*

  Writes some informative text to the buffer.

- *aisu.ControlBuffer.warn(text)*

  Writes a warning to the buffer.

- *aisu.ControlBuffer.error(text)*

  Writes an error to the buffer.

- *aisu.ControlBuffer.open_prompt()*

  Opens up a prompt for user input. The result can be obtained by calling
  ``aisu.yield!``.

- *aisu.ControlBuffer.ask(text, flair)*

  Writes the text followed by a newline with the given flair, followed by
  opening the prompt. The text will be written until the user enters either
  ``y`` or ``n``. If ``y`` was entered, ``true`` will be returned; otherwise,
  ``false`` will be returned.

- *aisu.ControlBuffer.call(f, ...)*

  Calls the given function with the variadic arguments. If an error occurs,
  then the traceback will be written to the buffer, and the error will be
  re-raised.

Commands
^^^^^^^^

- *aisu.map_packages(buffer, packages, fn, ...)*

  Splits the string ``packages`` by spaces. For each resulting package, calls
  ``fn(buffer, package, ...)``.

- *aisu.query_info_from_repo(dir)*

  Search for ``aisu.moon`` and ``init.moon`` and return the Aisu config table.
  It's formatted like this::

    {
      meta:
        author: '...'
        description: '...'
        license: '...'
      build: build_function_here
    }

  Any of the fields may be missing/``nil``.

- *aisu.perform_query(buffer, package, after)*

  Queries for information on the given package. After the query is complete,
  calls **after(buffer, package_url, temporary_directory_holding_repo,
  version_control_class, package_information_like_query_info_from_repo)**.

- *aisu.show_query(buffer, url, dir, vcs, info)*

  Writes the package information to the buffer. Designed to be called by
  ``aisu.perform_query``.

- *aisu.build_package(buffer, build_function, dir)*

  Calls the given build function. ``dir`` is the directory holding the package.

- *aisu.show_query(buffer, url, dir, vcs, info)*

  Installs the given package. Designed to be called by ``aisu.perform_query``.

- *aisu.uninstall_package(package)*

  Uninstalls the given package.

- *aisu.update_package(package)*

  Uninstalls the given package.
