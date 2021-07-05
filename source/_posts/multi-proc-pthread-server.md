---
title: 多进程、线程并发服务器
tags:
  - Linux
  - 多线程
  - 多进程
categories:
  - Linux
date: 2021-07-05 22:49:13
---
# 多进程、线程并发服务器

## 多进程并发服务器

### server.c

```c
#include <stdio.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <ctype.h>
#include <strings.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "wrap.h"
#define SERV_PORT 8888

void wait_chld(int signo)
{
  while(waitpid(0, NULL, WNOHANG) > 0); // 0：回收属于同一进程组的所有子进程， WNOHANG：不阻塞
  return;
}

int main(void)
{
        pid_t pid;
        int i, n;
        int lfd, cfd;
        struct sockaddr_in serv_addr, clie_addr;
        socklen_t clie_addr_len;
        char buf[1024] = {0};
        char clientip[1024] = {0};
        lfd = Socket(AF_INET, SOCK_STREAM, 0);

        bzero(&serv_addr, sizeof(serv_addr));

        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERV_PORT);
        serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
        //inet_pton(AF_INET, "192.168.10.100", &serv_addr.sin_addr.s_addr);
        Bind(lfd, (const struct sockaddr *)&serv_addr, (socklen_t)sizeof(serv_addr));

        Listen(lfd, 128); // 操作系统运行最大监听数为128

        while(1)
        {
                clie_addr_len = sizeof(clie_addr);
                cfd = Accept(lfd, (struct sockaddr *)&clie_addr, &clie_addr_len);
                printf("client ip:%s, port:%d\n", inet_ntop(AF_INET, &clie_addr.sin_addr.s_addr, clientip, sizeof(clientip)),
                                ntohs(clie_addr.sin_port));

                pid = fork();
                if(pid < 0)
                {
                        perror("fork error");
                        exit(1);
                }
                else if(pid == 0)
                {
                        close(lfd);
                        break;
                }
                else
                {
                        close(cfd);
                        signal(SIGCHLD, wait_chld);
                }
        }
    
        if(pid == 0)
        {
                while(1)
                {
                        n = Read(cfd, buf, sizeof(buf));
                        if(n == 0) // 0表示对方连接断开
                        {
                                close(cfd);
                                return 0;
                        }
                        else if(n == -1)
                        {
                                perror("read error");
                                exit(1);
                        }
                        else
                        {
                                for(i = 0; i < n; i++)
                                {
                                        buf[i] = toupper(buf[i]);
                                }
                                write(cfd, buf, n);
                                write(STDOUT_FILENO, buf, n);
                        }
                }
        }
        return 0;
}
```

### wrap.c

```c
#include <stdio.h>
#include <wrap.h>
#include <unistd.h>
#include <errno.h>
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

  do {

    if ((n = accept(sockfd, addr, addrlen)) < 0)
    {
      if((errno == ECONNABORTED) || (errno == EINTR))
      {

      }
      else
      {
        err_sys("accept error");
        break;
      }
    }
  } while(n < 0);
  return (n);

}

int Connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen)
{
  int n;
  if ((n = connect(sockfd, addr, addrlen)) < 0)
    err_sys("connect error");
  return (n);

}

ssize_t Read(int fd, void *buf, size_t count)
{
  ssize_t n;

again:
  if((n = read(fd, buf, count)) == -1)
  {
    if(errno == EINTR)
    {
      goto again;
    }
    return -1;
  }

  return n;
}

ssize_t Write(int fd, const void *buf, size_t count)
{
  ssize_t n;

  do {
    if((n = write(fd, buf, count)) == -1)
    {
      if(errno != EINTR)
      {
        return -1;
      }
    }
  } while(n != -1);

  return n;
}

int Close(int fd)
{
  int n;
  if((n = close(fd)) == -1)
      err_sys("connect error");
  return n;
}

ssize_t Readn(int fd, void *vptr, ssize_t n)
{
  size_t nleft;   // unsigned int 剩余未读取的字节数
  ssize_t nread;  // int 实际读到的字节数

  const char *ptr = vptr;
  nleft = n;      // n 未读取的字节数


  while(nleft > 0)
  {
    if((nread = read(fd, (void *)ptr, nleft)) < 0)
    {
      if(errno == EINTR)
        nread = 0;
      else
        return -1;
    }
    else if(nread == 0)
      break;

    nleft -= nread;
    ptr += nread;
  }

  return n - nleft;
}

ssize_t Writen(int fd, const void *vptr, size_t n)
{
  size_t nleft;   // unsigned int 剩余未写出的字节数
  ssize_t nwriten;  // int 实际写出的字节数

  const char *ptr = vptr;
  nleft = n;      // n 未写出的字节数


  while(nleft > 0)
  {
    if((nwriten = write(fd, ptr, nleft)) <= 0)
    {
      if(errno == EINTR && nwriten < 0)
        nwriten = 0;
      else
        return -1;
    }
    else if(nwriten == 0)
      break;

    nleft -= nwriten;
    ptr += nwriten;
  }

  return n - nleft;

}
```

### wrap.h

```c
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
ssize_t Read(int fd, void *buf, size_t count);
ssize_t Write(int fd, const void *buf, size_t count);
int Close(int fd);
ssize_t Readn(int fd, void *vptr, ssize_t n);
ssize_t Writen(int fd, const void *vptr, size_t n);

#endif
```

### Makefile

```makefile
all : server
.PHONY : all

src = $(wildcard ./*.c) # wildcard函数：显示指定路径下指定文件类型的所有文件
obj = $(patsubst ./%.c, ./%.o, $(src)) # patsubst函数：.c 替换成 .o

# LIBS := -lpthread
CFLAGS = -I. -g -Wall
CC = gcc
CXX = g++

server : $(obj)
        $(CC) -o server $(obj) $(CFLAGS) $(LIBS)

# $@  表示目标文件
# $<  表示第一个依赖文件
%.o : %.c
        $(CC) -c $(CFLAGS) $< -o $@


# -  即使出错也继续执行后面
.PHONY : clean  # .PHONY 伪目标，有了这句，不管怎样都执行clean
clean :
        -$(RM) server  $(obj)
```

## 多线程并发服务器

### server.c

```c
#include <stdio.h>
#include <arpa/inet.h>
#include <ctype.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <fcntl.h>
#include "wrap.h"

#define MAXSIZE 8192
#define SERV_PORT 8888
// 定义i一个结构体，将结构体跟cfd捆绑
struct s_info{
  struct sockaddr_in clieaddr;
  int connfd;
};


void *dowork(void * arg)
{
  int n, i;
  struct s_info *ts = (struct s_info *)arg;
  char buf[MAXSIZE] = {0};
  char str[INET_ADDRSTRLEN]; // #define INET_ADDRSRTLEN 16 可用"[+d"查看

  while(1)
  {
    n = Read(ts->connfd, buf, MAXSIZE);   // 读客户端
    if(n == 0)
    {
      printf("the client %d closed...\n", ts->connfd);
      break; // 对端关闭连接
    }
    printf("reaeived from %s at port %d",
                    inet_ntop(AF_INET, &ts->clieaddr.sin_addr.s_addr, str, sizeof(str)),
                    ntohs(ts->clieaddr.sin_port)); // 打印客户端信息

    for(i = 0; i < n; i++)
    {
      buf[i] = toupper(buf[i]);
    }

    Write(STDOUT_FILENO, buf, n); // 打印到屏幕
    Write(ts->connfd, buf, n);  // 回显给客户端

  }
  Close(ts->connfd);
  return (void *)0;
}

int main(void)
{
        int i;
        int lfd, cfd;
        struct sockaddr_in serv_addr, clie_addr;
        socklen_t clie_addr_len;
        pthread_t tid;
        struct s_info ts[256]; // 根据最大线程数创建结数组
        char clientip[256];

        lfd = Socket(AF_INET, SOCK_STREAM, 0);

        bzero(&serv_addr, sizeof(serv_addr));

        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERV_PORT);
        serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);  // 指定本地任意IP
        //inet_pton(AF_INET, "192.168.10.100", &serv_addr.sin_addr.s_addr);
        Bind(lfd, (const struct sockaddr *)&serv_addr, (socklen_t)sizeof(serv_addr));

        Listen(lfd, 128); // 设置同一时刻连接服务器的上限，操作系统运行最大监听数为128

        printf("Accepting client connect ...\n");
        while(1)
        {
                clie_addr_len = sizeof(clie_addr);
                cfd = Accept(lfd, (struct sockaddr *)&clie_addr, &clie_addr_len); // 阻塞监听客户端连接请求
                printf("client ip:%s, port:%d\n", inet_ntop(AF_INET, &clie_addr.sin_addr.s_addr, clientip, sizeof(clientip)),
                                ntohs(clie_addr.sin_port));
                ts[i].clieaddr = clie_addr;
                ts[i].connfd = cfd;

                /* 达到最大线程数时，pthread_create出错处理，增加系统服务稳定性*/
                pthread_create(&tid, NULL, dowork, (void *)&ts[i]);
                pthread_detach(tid); // 子线程分离，防止僵尸线程产生
                i++;
        }
        return 0;
}
```

### wrap.c

跟前面多进程版一致

### wrap.h

跟前面多进程版一致

### Makefile

```makefile
all : server
.PHONY : all

src = $(wildcard ./*.c) # wildcard函数：显示指定路径下指定文件类型的所有文件
obj = $(patsubst ./%.c, ./%.o, $(src)) # patsubst函数：.c 替换成 .o

LIBS := -lpthread #相比多进程只是多了这一句，这句为链接线程库pthread
CFLAGS = -I. -g -Wall
CC = gcc
CXX = g++

server : $(obj)
        $(CC) -o server $(obj) $(CFLAGS) $(LIBS)

# $@  表示目标文件
# $<  表示第一个依赖文件
%.o : %.c
        $(CC) -c $(CFLAGS) $< -o $@


# -  即使出错也继续执行后面
.PHONY : clean  # .PHONY 伪目标，有了这句，不管怎样都执行clean
clean :
        -$(RM) server  $(obj)
```
