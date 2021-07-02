---
title: 进程间通信IPC
tags:
  - IPC
  - 进程间通信
categories:
  - Linux
date: 2021-06-29 01:25:18
---
# 进程间通信IPC

IPC（Inter-Process Communication，进程间通信）。进程间通信是指两个进程的数据之间产生交互。

## 1、管道

### 1.1基本概念

管道是一种最基本的IPC机制，作用于有血缘关系的进程之间，完成数据传递。调用pipe系统函数即可创建一个管道。

- 本质是一个伪文件（实为内核缓冲区）。
- 有两个文件描述符，一个表示读端(`fd[1]`)，一个表示写端(`fd[0]`)。
- 规定数据从管道的写端流入，从读端流出。
- 双向半双工。

原理：管道实为内核使用环形队列机制，借助内核缓冲区（4k）实现。

缺点：

- 数据只能自己读不能自己写。
- 数据一旦被读走，便不存在管道中，不可反复读取。
- 半双工，数据只能在一个方向上流动。
- 只能在有公共祖先的进程间使用。

查看系统用户所有限制值的命令：`ulimit -a`

```shell
root@iZwz94euuu9omhoocm3l5uZ:~# ulimit -a
core file size          (blocks, -c) 0
data seg size           (kbytes, -d) unlimited
scheduling priority             (-e) 0
file size               (blocks, -f) unlimited
pending signals                 (-i) 7725
max locked memory       (kbytes, -l) 65536
max memory size         (kbytes, -m) unlimited
open files                      (-n) 65535
pipe size            (512 bytes, -p) 8
POSIX message queues     (bytes, -q) 819200
real-time priority              (-r) 0
stack size              (kbytes, -s) 8192
cpu time               (seconds, -t) unlimited
max user processes              (-u) 7725
virtual memory          (kbytes, -v) unlimited
file locks                      (-x) unlimited
```

`pipe size = 512bytes * 8 = 4KBytes`	,512bytes为磁盘的一个扇区大小。

### 1.2pipe函数

```c
#include <sys/wait.h>
int pipe(int pipefd[2]);
```

- 参数：`pipefd[0]`为读端，`pipefd[1]`为写端
- 返回值：成功：0；失败：-1，设置errno

### 1.3例子

```c
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
int main(void)
{
  int fd[2];
  pid_t pid;

  int ret = pipe(fd);
  if(ret == -1)
  {
    perror("pipe error:");
    exit(1);
  }
  pid = fork();
  if(pid == -1)
  {
    perror("fork error:");
    exit(1);
  }
  else if(pid == 0) // 子进程 读数据
  {

    char buf[1024] = {0};
    close(fd[1]);
    ret = read(fd[0], buf, sizeof(buf));
    if(ret == 0)
    {
      printf("----\n");
    }
    write(STDOUT_FILENO, buf, ret);
    close(fd[0]);
  }
  else // 父进程 写数据
  {
    close(fd[0]);
    char *data = "hello pipe\n";
    printf("len = %ld\n", sizeof(data));
    write(fd[1], data, strlen(data));
    wait(NULL); // 阻塞回收子线程资源，避免子进程成为僵尸进程
    close(fd[1]);

  }

  return 0;
}

```

### 1.4读写管道的特点

-  读管道：

   -  管道中有数据，read返回实际读到的字节数。

   -  管道中无数据：

      - 管道写端被全部关闭，read返回0 (好像读到文件结尾)

      - 写端没有全部被关闭，read阻塞等待(不久的将来可能有数据递达，此时会让出cpu)

-  写管道： 

   -  管道读端全部被关闭， 进程异常终止(也可使用捕捉SIGPIPE信号，使进程不终止)
   -  管道读端没有全部关闭：
      - 管道已满，write阻塞。
      - 管道未满，write将数据写入，并返回实际写入的字节数。

## 2、共享内存

### 2.1基本概念

共享内存就是映射一段能被其它进程所访问的内存，这段共享内存由一个进程创建，但其它的多个进程
都可以访问，使得多个进程可以访问同一块内存空间。

特点：

- 共享内存是最快的一种 IPC，因为进程是直接对内存进行存取。
- 管道和消息队列等通信方式，需要在内核和用户空间进行四次的数据拷贝，而共享内存则只拷贝两次：一次从输入文件到共享内存，另一次从共享内存到输出文件。
- 因为多个进程可以同时操作，所以需要进行同步。
- 一般和信号量一起使用，信号量用来同步对共享内存的访问。

### 2.2相关函数

**创建共享内存映射**：

```c
#include <sys/mman.h>
void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
```

参数：

- addr：建立映射区的首地址，由Linux内核指定。使用时，写NULL即可。

- length：要创建映射区的大小。

- prot：映射区权限 `PORT_READ` 、`PORT_WRITE`、 `PORT_READ | PORT_WRITE`。

- flags：标志位参数（常用于设定更新物理地址、设置共享、创建匿名映射区）。

  ​			`MAP_SHARED`：将映射区所做的操作反映到物理设备（磁盘）上。

  ​			`MAP_PRIVATE`：映射区所做的修改不会反映到物理设备上。

- fd：用来建立映射区的文件描述符。

- offset：映射文件的偏移（一定要是4k的整数倍）。

返回值：成功返回创建的映射区首地址；失败返回`MAP_FAILED`宏。

**解除共享内存映射**：

```c
#include <sys/mman.h>
int munmap(void *addr, size_t length);
```

参数：

- addr：映射区的首地址。
- length：映射区的大小。

返回值：成功返回0；失败返回-1。

**一定要注意：**

1. 创建映射区的时候，隐含着一次对映射文件的读操作。
2. 当`MAP_SHARED`时，要求：映射区的权限应 <= 文件打开的权限（出于对映射区的保护）。而`MAP_PRIVATE`则无所谓，因为`mmap` 中的权限是对内存的限制。
3. 映射区的释放和文件关闭无关。只要映射成功，文件可以立刻关闭。
4. 特别注意：当映射文件大小为0时，不能创建映射区。所以：用于映射的文件必须要有实际的大小！！！`mmap`使用时常出现总线错误，通常是因为共享文件存储空间大小引起的。
5. `munmap`传入的地址一定要是`mmap`返回的地址。坚决杜绝指针++操作。
6. 如果文件偏移量必须为4k的整数倍。
7. `mmap`创建的映射区出错概率非常高，一定要检查返回值，确保映射区建立成功后才进行后续操作。

### 2.3例子

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <string.h>

#define MY_MMAP_SIZE 20
#define MY_MMAP_FILE "temp"

int main(void)
{
    char *p = NULL;
    pid_t pid;

    int fd;
    fd = open(MY_MMAP_FILE, O_RDWR|O_CREAT|O_TRUNC, 0644);
    if(fd < 0){
        perror("open error");
        exit(1);
    }
    unlink(MY_MMAP_FILE);        //删除临时文件目录项
    ftruncate(fd, MY_MMAP_SIZE);
    p = (char *)mmap(NULL, MY_MMAP_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if(p == MAP_FAILED) { // 注意，不是 p == NULL
        perror("mmap error");
    exit(1);
    }
    close(fd);                   //映射区建立完毕,即可关闭文件

    pid = fork();                               //创建子进程
    if(pid == 0){
       char *data = "child hello!\n";
        strncpy(p, data, strlen(data) + 1);
       // *p = 1234;
        printf("son, *p = %s\n", p);
    } else {
        sleep(1);
        printf("parent, *p = %s\n", p);
        wait(NULL);

        int ret = munmap(p, MY_MMAP_SIZE);                 //释放映射区
        if (ret == -1) {
            perror("munmap error");
            exit(1);
        }
    }

    return 0;
}
```

```c
// 匿名映射方式，不要创建临时文件temp
// MAP_ANONYMOUS linux下才有此宏，类unix系统没有
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <string.h>

#define MY_MMAP_SIZE 20

int main(void)
{
    char *p = NULL;
    pid_t pid;

    p = (char *)mmap(NULL, MY_MMAP_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if(p == MAP_FAILED) { // 注意，不是 p == NULL
        perror("mmap error");
    exit(1);
    }

    pid = fork();                               //创建子进程
    if(pid == 0){
       char *data = "child hello!\n";
        strncpy(p, data, strlen(data) + 1);
       // *p = 1234;
        printf("son, *p = %s\n", p);
    } else {
        sleep(1);
        printf("parent, *p = %s\n", p);
        wait(NULL);

        int ret = munmap(p, MY_MMAP_SIZE);                 //释放映射区
        if (ret == -1) {
            perror("munmap error");
            exit(1);
        }
    }

    return 0;
}
```

```c
// 类unix系统的匿名映射方法，Linux也可以使用
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <string.h>

#define MY_MMAP_SIZE 20
#define MY_MMAP_FILE "/dev/zero"

int main(void)
{
    char *p = NULL;
    pid_t pid;

    int fd;
    fd = open(MY_MMAP_FILE, O_RDWR);
    if(fd < 0){
        perror("open error");
        exit(1);
    }

    p = (char *)mmap(NULL, MY_MMAP_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if(p == MAP_FAILED) { // 注意，不是 p == NULL
        perror("mmap error");
    exit(1);
    }
    close(fd);                   //映射区建立完毕,即可关闭文件

    pid = fork();                               //创建子进程
    if(pid == 0){
       char *data = "child hello!\n";
        strncpy(p, data, strlen(data) + 1);
       // *p = 1234;
        printf("son, *p = %s\n", p);
    } else {
        sleep(1);
        printf("parent, *p = %s\n", p);
        wait(NULL);

        int ret = munmap(p, MY_MMAP_SIZE);                 //释放映射区
        if (ret == -1) {
            perror("munmap error");
            exit(1);
        }
    }

    return 0;
}
```

- `/dev/zero`：在类UNIX 操作系统中, `/dev/zero` 是一个伪文件。
  - 产生连续不断的null的流 （二进制的零流，而不是ASCII型的）。
  - 写入它的输出会丢失不见 。
  - 主要的用处是用来创建一个指定长度用于初始化的空文件，像临时交换文件。
  - 为特定的目的而用零去填充一个指定大小的文件，如挂载一个文件系统到环回设备 （`loopback device`） 或"安全地" 删除一个文件。
- `/dev/null`：在类Unix系统中，`/dev/null`，或称空设备，是一个特殊的设备文件，它丢弃一切写入其中的数据（但报告写入操作成功），读取它则会立即得到一个`EOF`。
  - 被称为位桶(`bit bucket`)或者黑洞(`black hole`)。
  - 通常被用于丢弃不需要的输出流，或作为用于输入流的空文件。这些操作通常由重定向完成。
  - 等价于一个只写文件，并且所有写入它的内容都会永远丢失，而尝试从它那儿读取内容则什么也读不到。
  - `cat $filename >/dev/nul`l 则不会得到任何信息，因为我们将本来该通过标准输出显示的文件信息重定向到了 `/dev/null` 中。

```c
// mmap_wr.c
#include<stdio.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>
#include<string.h>
#include<stdlib.h>
#include<sys/mman.h>


struct STU{
    int id;
    char name[20];
    char sex;
};


void sys_err(char *str)
{
    perror(str);
    exit(1);
}

int main(int argc,char *argv[])
{
    int fd;
    struct STU student = {10, "xiaoming", 'm'};
    struct STU *mm;


    if(argc < 2){
        printf("./a.out file_shared\n");
        exit(-1);
    }


    fd = open(argv[1],O_RDWR | O_CREAT, 0664);
    ftruncate(fd,sizeof(student));


    mm = mmap(NULL, sizeof(student), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (mm == MAP_FAILED)
        sys_err("mmap error");


    close(fd);


    while (1) {
        memcpy(mm, &student, sizeof(student));
        student.id++;
        sleep(1);
    }


    munmap(mm, sizeof(student));
    return 0;
}
```

```c
// mmap_rd.c
#include<stdio.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>
#include<string.h>
#include<stdlib.h>
#include<sys/mman.h>


struct STU{
    int id;
    char name[20];
    char sex;
};


void sys_err(char *str)
{
    perror(str);
    exit(1);
}


int main(int argc,char *argv[])
{
    int fd;
    struct STU student;
    struct STU *mm;


    if(argc < 2){
        printf("./a.out file_shared\n");
        exit(-1);
    }


    fd = open(argv[1],O_RDONLY);
    if (fd == -1)
    sys_err("open error");

    mm = mmap(NULL,sizeof(student),PROT_READ,MAP_SHARED,fd,0);
    if (mm == MAP_FAILED)
        sys_err("mmap error");


    close(fd);


    while (1) {
        printf("id=%d\tname=%s\t%c\n", mm->id, mm->name, mm->sex);
        sleep(2);
    }
    munmap(mm, sizeof(student));
    return 0;


}
```

## 3、套接字（socket）

### 3.1基本概念

`socket`套接字本身是为网络通信而设计的，但后来在`socket`的框架上发展出一种`IPC`机制，就是`Unix Domain Socket`。使用`Unix Domain Socket`的过程跟网络`socket`十分相似，也要先调用`socket()`创建一个`socket`文件描述符，`address_family`指定为`AF_UNIX`，`type`可以选择`SOCK_DGRAM`或者`SOCK_STREAM`，`protocol`参数仍然指定为0即可。

`Unix Domain Socket`与网络`socket`编程的区别。

- `Unix Domain Socket`：。

  - 地址格式结构体为`sockaddr_un`，`un`表示Unix。

  - 地址是一个`socket`类型的文件在文件系统中的路径，这个`socket`文件由`bind()`调用创建，如果调用`bind()`时该文件已存在，则`bind()`错误返回。

    ```c
    struct sockaddr_un {
       __kernel_sa_family sun_family;   /* AF_UNIX */  地址结构类型
       char sun_path[UNIX_PATH_MAX];	/* pathname */ socket文件名（含路径）
    };
    ```

  - 将`Unix Domain socket`绑定到一个地址。

    ```c
    size = offsetof(struct sockaddr_un, sunpath) + strlen(un.sun_path);
    #define offsetof(type, member) ((int)&((type *)0)->MEMBER)
    ```

- 网络`socket`编程：

  - 地址格式结构体为`sockaddr_in`，`in`表示Internet。

  - 地址是IP地址加上端口号。

    ```c
    struct sockaddr_in {
        __kernel_sa_family_t sin_family; /* Address family */  地址结构类型
        __be16 sin_port;                 /* Port number */     端口号
        struct in_addr sin_addr;         /* Internet address */ip地址
    };
    ```

### 3.2例子

```c
// socket_server.c
#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <sys/un.h>
#include <stdlib.h>
#include "wrap.h"
#define SERVER_ADDR "server.socket"
#define SERVER_CONNECT_MAX 20

#define rdbuf_size 4096

int main(void)
{
  int lfd, cfd, len, size;
  struct sockaddr_un serveraddr, clientaddr;
  char rdbuf[rdbuf_size] = {0};

  lfd = Socket(AF_UNIX, SOCK_STREAM, 0);

  bzero(&serveraddr, sizeof(serveraddr));
  serveraddr.sun_family = AF_UNIX;
  strncpy(serveraddr.sun_path, SERVER_ADDR, sizeof(SERVER_ADDR));

  len = offsetof(struct sockaddr_un, sun_path) + strlen(serveraddr.sun_path); // serveraddr total len
  
  unlink(SERVER_ADDR);    // 确保bind之前 server.socket 文件不存在，bind() 会创建该文件
  Bind(lfd, (struct sockaddr *)&serveraddr, len); // 参3不能是 sizeof(serveraddr)

  Listen(lfd, SERVER_CONNECT_MAX);

  printf("Accept...\n");

  while(1)
  {
    len = sizeof(clientaddr); // 好像不用这句也行
    cfd = Accept(lfd, (struct sockaddr *)&clientaddr, (socklen_t *)&len);

    len -= offsetof(struct sockaddr_un, sun_path); // 等到文件名的长度
    clientaddr.sun_path[len] = '\0'; // 确保打印时没有乱码

    printf("client bind filename %s \n", clientaddr.sun_path);

    while((size = read(cfd, rdbuf, rdbuf_size)) > 0)
    {
      for(int i = 0; i < size; i++)
              rdbuf[i] = toupper(rdbuf[i]);
      int tmp = size;
      do {
        int tmp2 = write(cfd, rdbuf, tmp);
        if(tmp2 == -1)
        {
                perror("write error:");
                break;
        }
        tmp -= tmp2; 
      } while(tmp > 0);
    }
    close(cfd);
  }
  close(lfd);

  return 0;
  
}
```

```c
// socket_client.c
#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <sys/un.h>
#include "wrap.h"

#define SERVER_ADDR "server.socket"
#define CLIENT_ADDR "client.socket"
#define FGETS_BUF_SIZE 4096


int main(void)
{
  int cfd, len;
  struct sockaddr_un serveraddr, clientaddr;
  char buf[FGETS_BUF_SIZE] = {0};

  cfd = Socket(AF_UNIX, SOCK_STREAM, 0);

  bzero(&clientaddr, sizeof(clientaddr));
  clientaddr.sun_family = AF_UNIX;
  strncpy(clientaddr.sun_path, CLIENT_ADDR, sizeof(CLIENT_ADDR));

  len = offsetof(struct sockaddr_un, sun_path) + strlen(clientaddr.sun_path); // 计算客户端地质结构有效长度

  unlink(CLIENT_ADDR);
  Bind(cfd, (struct sockaddr *)&clientaddr, len); // 客户端也需要bind，不能依赖自动绑定

  bzero(&serveraddr, sizeof(serveraddr));  // 构造server地址
  serveraddr.sun_family = AF_UNIX;
  strncpy(serveraddr.sun_path, SERVER_ADDR, sizeof(SERVER_ADDR));

  len = offsetof(struct sockaddr_un, sun_path) + strlen(serveraddr.sun_path); //计算服务器地址结构有效长度

  Connect(cfd, (struct sockaddr *)&serveraddr, len);

  while(fgets(buf, sizeof(buf), stdin) != NULL)
  {
    write(cfd, buf, strlen(buf));
    len = read(cfd, buf, sizeof(buf));
    write(STDOUT_FILENO, buf, len);
  
  }
  close(cfd);
        
}
```

```c
// wrap.c 这里是socket的包裹函数
#include <stdio.h>
#include <wrap.h>
void err_sys(const char* x) 
{ 
    perror(x); 
    exit(1); 
}

int Socket(int domain, int type, int protocol)
{
  int n;
  if ((n = socket(domain, type, protocol)) < 0)
    err_sys("socket error");
  return (n);
}

int Bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen)
{
  int n;
  if ((n = bind(sockfd, addr, addrlen)) < 0)
    err_sys("bind error");
  return (n);

}

int Listen(int sockfd, int backlog)
{
  int n;
  if ((n = listen(sockfd, backlog)) < 0)
    err_sys("listen error");
  return (n);
  
}

int Accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen)
{
  int n;
  if ((n = accept(sockfd, addr, addrlen)) < 0)
    err_sys("accept error");
  return (n);
  
}

int Connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen)
{
  int n;
  if ((n = connect(sockfd, addr, addrlen)) < 0)
    err_sys("connect error");
  return (n);
  
}
```

```c
// wrap.h
#ifndef __WRAP_H
#define __WRAP_H

#include <stdlib.h>
#include <sys/types.h>          /* See NOTES */
#include <sys/socket.h>

#define offsetof(type, member) ((int)&((type *)0)->member)

int Socket(int domain, int type, int protocol);
int Bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
int Listen(int sockfd, int backlog);
int Accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
int Connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

#endif
```

```makefile
# 这个makefile写不是很好，有待整改
all : socket_client socket_server
.PHONY : all

RM_TARGET = socket_client socket_server

CLIENT_OBJS = socket_client.o wrap.o
SERVER_OBJS = socket_server.o wrap.o

# LIBS := -lpthread
CFLAGS = -I. -g
CC = gcc
CXX = g++

socket_client : $(CLIENT_OBJS)
	$(CC) -o socket_client $(CLIENT_OBJS) $(CFLAGS) $(LIBS)

socket_server : $(SERVER_OBJS)
	$(CC) -o socket_server $(SERVER_OBJS) $(CFLAGS) $(LIBS)

$(CLIENT_OBJS) : %.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(SERVER_OBJS) : %.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@

.PHONY : clean
clean :
	-$(RM) socket_server socket_client  $(CLIENT_OBJS) $(SERVER_OBJS)

```

