Vim color picker script for OS X
===

> The Support OS X’s Color picker thread on the MacVim mailinglist made me hack on a little vim script that lets you select a color in OS X’s color picker and automatically insert it at the current postition in the buffer.
This can for example be useful for web developers who are editing their CSS files with Vim or similar tasks.

![image](https://github.com/iandoe/vim-osx-colorpicker/raw/master/screenshot.png)

* Author : Maximilian Nickel
* License: [BSD](http://www.opensource.org/licenses/bsd-license.php)
* Original link: [2manyvariables](http://2manyvariables.inmachina.com/2010/03/macvim-color-picker-script/)

PS: For those of you wondering, the css color highlight in vim is [the vim-css-color plugin](https://github.com/skammer/vim-css-color)


Usage
---
```viml
"to insert hex values at the current position
:ColorHEX
"to insert RGB values at the current position
:ColorRGB
```

The plugin detects if you're running MacVim and falls back to Terminal.app. If you want to use iTerm, do this:

```viml
let g:colorpicker_app = 'iTerm.app'
```

Changelog
---
### Update (2012-06-03)

Hosting to github so it's not lost.

### Update (2010-10-01)

Updated to version 0.3. New feature: pick up the hex color code under the cursor.

### Update (2010-03-13)

Uploaded new version 0.2 that keeps the focus on MacVim or the Terminal and checks for OS X. Also renamed the script to colorx.vim
The script is now also hosted at Vim scripts
