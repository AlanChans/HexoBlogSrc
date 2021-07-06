---
title: 基本的Makefile使用
tags:
  - Linux
  - Makefile
categories:
  - Makefile
date: 2021-07-07 00:24:07
---
# Makefile

## 基本概念

makefile是一个代码管理工具，它定义了一系列的规则来指定那些文件需要先编译，哪些文件需要后编译，哪些文件需要重新编译。

最大的好处就是，只要把makefile写好，然后执行一个make命令就完成所有的编译了。

不然每次编译都要敲一大串命令，很容易把我们累死。例如：

```shell
gcc *.c -Include ./ -Wall -g -O3 -D DEBUG -L
```

## makefile的命名

makefile命名只有两种情况，任选其一即可：makefile、Makefile。

## makefile的规则

规则中的三要素：目标，依赖，规则。一条规则的形式如下：

> 目标：依赖条件
>
> ​	命令

注意命令前面必须是一个Table缩进。

如果makefile中有多条规则，则默认第一条规则中的目标是我们的终极目标。makefile向下检索，构建出一颗关系树，从下往上执行命令。

make命令生成的目标都是终极目标。

![makefile工作原理.png](https://i.loli.net/2021/07/07/5IrjAsQVm8TaPDC.png)

例子：

```makefile
main:main.c sub.c add.c
	gcc main.c sub.c add.c -o main
```

可见，目标就是我们想要生成的文件，依赖就是我们的源文件，命令就是我们用依赖生成目标的命令，例如这里的就是gcc编译的命令。

上面例子是makefile和main.c 、sub.c、add.c是处于同一目录下的，如果不处于同一目录，需要显示指出源文件的目录。

## makefile的分文件编译

当一个项目的源文件很多很多时，需要对文件的进行分文件编译，否则修改了其中一个源文件，就会导致整个项目的源文件都重新编译了一次，浪费时间。

```makefile
main:main.o sub.o add.o
	gcc main.o sub.o add.o

main.o:main.c
	gcc -c main.c
	
sub.o:sub.c
	gcc -c sub.c

add.o:add.c
	gcc -c add.c
```

## makefile的变量

makefile定义变量不需要数据类型，直接定义即可，但要取变量里的内容则需在其前加`$`符号，一般也会将变量用`()`括起来。

```makefile
obj = main.o sub.o add.o
target = main

$(target):$(obj)
	gcc $(obj) -o $(target)
	
main.o:main.c
	gcc -c main.c
	
sub.o:sub.c
	gcc -c sub.c

add.o:add.c
	gcc -c add.c
```

## makefile的自动变量

%<：规则中的第一个依赖

%@：规则中的目标

%^：规则中的所有依赖

**只能在规则中的命令使用。**

## makefile的“="

| 符号 | 描述                               |
| ---- | ---------------------------------- |
| =    | 最基本的赋值                       |
| :=   | 覆盖之前的值                       |
| ?=   | 如果没有被赋值过就赋予等号后面的值 |
| +=   | 添加等号后面的值                   |

## makefile的模式规则

在规则的目标定义使用%，在规则的依赖条件使用%。

```makefile
obj = main.o sub.o add.o
target = main

$(target):$(obj)
	gcc $(obj) -o $(target)

%.o:%.c
	gcc -c $< -o $@
```

%.o:%.c 相当于 main.o:main.c、sub.0:sub.c、add.o:add.c。模式规则会帮我们自动匹配上。

## makefile自己维护的变量

特征：通常变量名全大写

CC：默认值为cc，cc其实也就是gcc。

CPPFLAGS：预处理的时候使用的参数。例如：

`CPPFLAGS = -I`预处理的时候指定头文件路径。

CFLAGS：编译的时候使用的参数。例如：

`CFLAGS = -Wall -g -c`编译的时候显示警告、加入调试信息、只编译

LDFLAGS：链接库的时候使用的选项。

`LDFLAGS = -L -l`链接库的时候指定库路径、库名。

```makefile
obj = main.o sub.o add.o
target = main
CC = gcc
CPPFLAGS = -I
$(target):$(obj)
	$(CC) $(obj) -o $(target)

%.o:%.c
	$(CC) -c $< -o $@
```

## makefile的函数

makefile中使用的所有函数都是有返回值的，函数名与参数通过空格分开，参数与参数之间通过逗号分开。

$(wildcard <pattern>...)

$(patsubst <pattern>,<replacement>,<text>)

一般这两个函数结合使用。wildcard 通过通配符找到相关的.c源文件，返回它们的字符串，再通过 patsubst 模式替换将.c源文件的名称的字符串替换成对应的.o目标文件。

```makefile
target = main
src = $(wildcard ./*.c)
obj = $(patsubst ./%.c, ./%.o, $(src))
CC = gcc
CPPFLAGS = -I
$(target):$(obj)
	$(CC) $(obj) -o $(target)

%.o:%.c
	$(CC) -c $< -o $@
```

## clean

伪目标，没有依赖。用于删除所有被 make 创建的文件。

```makefile
target = main
src = $(wildcard ./*.c)
obj = $(patsubst ./%.c, ./%.o, $(src))
CC = gcc
CPPFLAGS = -I
$(target):$(obj)
	$(CC) $(obj) -o $(target)

%.o:%.c
	$(CC) -c $< -o $@

.PHONY:clean
clean:
	-rm $(target) $(obj) -f
```

-：如果出错，忽略当前命令，继续向下执行下面的命令。

-f：强制执行，不管有没有对应的文件都删除。

.PHONY:clean：声明clean为伪目标。

