## SimpleMenu

・必要ファイル  
plugins/simplemenu.smx  
configs/simplemenu/menu.cfg

シンプルなメニュー表示プラグインです。  
１つのメニューを１つのcfgに記述し、複数のcfgを作成することによって複数のメニューやメニューの階層化が可能です。

**cmds**

>"sm_menu"  
>登録されたコマンドを実行するメニューを開きます。

引数としてcfgファイルを指定するとそのメニューを開きます。  
作成したcfgファイルはconfigs/simplemenu/に保存してください。  

cfgの記述方法はmenu.cfg内にあります。  

**cvars**

>"sm_menu_enable" = "1"  
>SimpleMenuの動作状態　1:有効 他:無効

>"sm_menu_default" = "menu.cfg"  
>デフォルトのメニューファイル名

cmdでcfgを指定しなかった場合に読み込むcfgファイル
