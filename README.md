# PELA的简单介绍及使用教程

PELA，N网近来最火的模组，私以为它跟CNS有着同等价值，虽然还在早期开发阶段，但未来可期

具体而言，你可以把它当做是游戏内的色情动画播放器，虽然有着类似功能的ATOOL模组早已存在（实际上PELA也依赖于ATOOL），但更简便的操作方式以及跟游戏玩法的结合使得PELA具备更高的上限

## 模组简介

首先，**使用PELA播放的所有动画都是可编辑的**，你可以通过改动json文件来决定哪几个动作拼接在一起形成动画、每个动作循环几次、以及在哪个动作/什么时间点伊芙会高潮

**并且这些动画能在游戏内随时播放**，你伊芙姐姐美美走在废土上突然来个雷霆色情表演这谁能绷得住

其次，**PELA扩展了游戏玩法，引入了欲望值的概念**，把剑星变成了真正的成人游戏，欲望值常态随时间累积，攒满之后会移动受限且持续扣血，按F5播放动画期间会消耗欲望值并恢复beta能量，如果高潮还能回血

**PELA还提供了一颗新的技能树**，都是跟欲望值相关的技能，你消耗的欲望值越多，你获得的经验值越多，累积经验可以获得技能加点，不过目前只解锁了两个技能且没有后续升级，期待作者后续更新

## 如何安装

所有你会用到的模组链接我都贴在下面了，有任何问题都可以提，祝你游玩愉快

模组的常规安装方法是直接复制SB到游戏安装目录，比如D:\Steam\steamapps\common\StellarBlade，如果我没特意说明将哪个文件夹放到哪里，那就是这种安装方式

-->安装UE4SS

-->安装ATOOL，将解压出来的HD_ATOOL_P放到SB\Content\Paks\LogicMods而不是SB\Content\Paks\~mods

-->安装PELA

-->安装动画包，把下载好的动画包都放到SB\Content\Paks\~mods，每个动画包都自带相应的音频文件，你可以在PakName\audio找到它们，把这些音频文件都剪切到SB\Content\Paks\LogicMods\HD_ATOOL_P\audio

## 如何使用

阅读PELA的描述页面中关于按键绑定的部分，支持手柄

如果你想改动触发动画的按键，请编辑SB\Binaries\Win64\ue4ss\Mods\LustyAndroid\Scripts\la_config.lua，具体位置在227行和239行，我暂时不知道在哪里修改技能的绑定按键

json文件可以在SB\Content\Paks\~mods\PELA Patches找到，阅读PELA的描述页面中关于PELA Patch Maker的部分，你会知道如何使用这些json文件来编辑动画

## 相关链接

### UE4SS
https://www.nexusmods.com/stellarblade/mods/2952

### ATOOL，**必须下载k3版本**
https://www.nexusmods.com/stellarblade/mods/1662

### PELA
https://www.nexusmods.com/stellarblade/mods/4108

### 动画包，**如果你之前安装过其他ATOOL动画包，请暂时把它们移除/编写新的json文件收容它们**

#### Masturbate，**必须下载链接指向的旧版本文件**
https://www.nexusmods.com/stellarblade/mods/3823?tab=files&file_id=16710

#### ESAP，**必须下载beta版本**
https://www.nexusmods.com/stellarblade/mods/3782

#### Adam
https://www.nexusmods.com/stellarblade/mods/3954

#### Behemoth
https://www.nexusmods.com/stellarblade/mods/3914

#### Lesbian
https://www.nexusmods.com/stellarblade/mods/3892

#### OldDroid
https://www.nexusmods.com/stellarblade/mods/3871

#### 还有一些动画包，在PELA0.3.0更新之后应该对应某些怪物的抓取动画，但我不会贴出来，因为我看不上制作这些动画的人

说的就是你，Exorbic，在评论区拆穿你抄袭PELA而我狠狠把你骂了一顿之后，你紧急把模组简介改成“此模组是一个动画库窗口，旨在展示剑星社区目前正在开发的动画”的样子真的很好笑，你之前是怎么写的用不用我帮你回忆一下？“哦，大家，想必你们都玩过什么什么游戏，那时我就对这种随时随地性交的功能产生痴迷了，现在我终于有机会把它实现了”，哈哈，疯狂修改模组描述企图在流量低社区还没有留档时把自己抄袭的事实掩盖过去，不敢跟我对线只敢在免责声明里阴阳怪气，然而又不得不把PELA的链接贴出来的时候想必你很高兴吧，把这一切都修改好之后再把我的评论置顶是想让别人来骂我么，说我冤枉你？你是不是可想看到那样的评论了？哪怕一条？可惜兄弟，可惜，这波贪了
