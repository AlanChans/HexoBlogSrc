---
title: Linux下线程的使用
date: 2021-06-25 20:29:54
tags: 
    - Linux
    - 线程进程
comments: true
copyright: 
top: 
photos: 
categories: 
    - Linux
    - 线程进程
---

# Linux下线程的使用

## 1、Linux线程

- 在早期的类Unix系统中是没有“线程”概念的，这是后面需求的才延伸出来的，它借助了进程机制实现出了线程的概念。因此在这类系统中，进程和线程关系密切。在Linux环境下的线程本质上还是进程，属于轻量级的进程（LWP：light weight process）。

- 实际上，无论是创建进程的fork，还是创建线程的pthread_create，底层实现都是调用同一个内核函数clone。
- fork复制对方的地址空间，产生一个“进程”；pthread_create共享对方的地址空间，就产生一个“线程”。

## 2、Linux线程创建

> 使用下面所有的线程相关函数都必须做的工作：
>
> 1、包含头文件  #include <pthread.h>
>
> 2、编译时链接线程库(线程库的名字叫pthread, 全名: libpthread.so libptread.a) -pthread

### 2.1获取线程ID（对应进程中 getpid() 函数）

每一个线程都对应一个唯一的线程 ID（两个进程间，线程ID允许相同），ID 类型为 pthread_t，这个 ID 是一个无符号长整形数(%lu)，如果想要获取当前线程的线程 ID，可以调用如下函数：

```c
pthread_t pthread_self(void);	// 返回当前线程的线程ID，man说这个函数总会执行成功
```

### 2.2创建线程函数（对应进程中fork() 函数）

```c
int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine) (void *), void *arg);
```

- 参数：
  - thread：传出参数，创建成功时保存系统为我们分配好的线程ID。
  - attr：通常传NULL，表示使用线程默认属性。也可自行修改。
  - start_routine：函数指针，指向线程任务函数(线程体)，该函数运行结束，则线程结束。该函数在子线程中执行。
  - arg：通过它把需要传递的参数传递到start_routine指向的函数体内部，如要传多个参数, 可以用结构封装。

- 返回值：成功返回0； 失败返回错误号。具体错误可通过strerror()函数输出。

### 2.3实例

```c
// my_pthread_create.c 
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

struct Test
{
    int num;
    int age;
};
void * mytask(void * arg)
{
    for (int i = 0; i < 5; i++)
    {
        printf("子线程：i = %d\n", i);
    }
    printf("子线程TID：%ld\n", pthread_self());

    struct Test * pt = (struct Test *)arg;
    pt->num = 1000;
    pt->age = 99;

    return NULL;
}
int main()
{
    pthread_t tid;
    struct Test test;

    pthread_create(&tid, NULL, mytask, &test);
    printf("子线程创建成功, 线程TID: %ld\n", tid);
    printf("主线程TID：%ld\n", pthread_self());

    return 0;
}
```

执行命令编译程序，`-lpthread`的意思是链接`pthread`线程库，要用线程相关函数除了包含头文件`#include <pthread.h>`以外，编译的时候还得指定链接线程库，否则编译失败。`-o app`的意思是指定输出的可执行文件名为`app`。

```shell
gcc my_pthread_create.c -lpthread -o app
```

```shell
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# gcc my_pthread_create.c -lpthread -o app
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# ls
app  my_pthread_create.c
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# ./app 
子线程创建成功, 线程TID: 139769949230848
主线程TID：139769949235008
root@iZwz94euuu9omhoocm3l5uZ:~/07_article#
```

编译执行后发现子线程虽然创建成功，但是子线程任务函数里面的打印并没有输出，原因是：

主线程一直在运行，执行期间创建出了子线程，接下来主线程和子线程“并发”，分道扬镳，各自执行自己的函数。子线程刚被创建出来，需要去抢CPU时间片，抢到了CPU时间片子线程的任务函数才能运行。

很明显，此时此刻，子线程并没有抢到CPU时间片，而主线程却抢到了。然后主线程去执行printf，执行完后发现没有工作要做了就直接返回退出了。

但主线程退出了, 虚拟地址空间就被释放了, 子线程就一并被销毁了，这样子线程任务函数里的printf就肯定没法运行了。

## 3、Linux线程退出

在多线程进程中，要让主线程退出不导致虚拟地址空间的释放，剩下的子线程继续正常运行，可以在主线程中调用线程退出函数。线程退出函数会让当前线程马上退出，而且不会释放虚拟地址空间，不会影响到其他线程的正常运行。线程退出函数可以在子线程或者主线程中都使用。

### 3.1线程退出函数

```c
void pthread_exit(void *retval);
```

- 参数：线程退出的时候携带的数据，当前子线程的主线程会得到该数据。如果不需要使用，指定为 NULL。一般使用的这个线程退出带出数据的功能的时候，需要在线程创建的时候把一块堆内存的指针传进去。

### 3.2实例

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

struct Test
{
    int num;
    int age;
};
void * mytask(void * arg)
{
    for (int i = 0; i < 10; i++)
    {
        printf("子线程：i = %d\n", i);
        if(i == 7)
        {
            pthread_exit(NULL); // 直接退出子线程
        }
    }
    printf("子线程TID：%ld\n", pthread_self());

    struct Test * pt = (struct Test *)arg;
    pt->num = 1000;
    pt->age = 99;

    return NULL;
}
int main()
{
    pthread_t tid;
    struct Test test;

    pthread_create(&tid, NULL, mytask, &test);
    printf("子线程创建成功, 线程TID: %ld\n", tid);
    printf("主线程TID：%ld\n", pthread_self());

    pthread_exit(NULL); // 主线程退出，不会释放虚拟地址空间，不影响子线程运行
    return 0;
}
```

编译执行结果：

```shell
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# gcc my_pthread_create.c -lpthread -o app
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# ./app 
子线程创建成功, 线程TID: 139901666547456
主线程TID：139901666551616
子线程：i = 0
子线程：i = 1
子线程：i = 2
子线程：i = 3
子线程：i = 4
子线程：i = 5
子线程：i = 6
子线程：i = 7
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# 
```

上面的程序执行结果说明，主线程执行`printf`就先退出了，此时虚拟地址空间还没有被释放，子线程继续执行`printf`，直到子线程执行到`pthread_exit`子线程就退出了，然后虚拟地址空间被释放，进程退出。

## 4、Linux线程回收

子线程在一般情况下都是由主线程创建并启动的，如果子线程相对主线程而言要进行大量的耗时的运算，那么主线程就会先于子线程结束，就好比如`3.2实例`。但是如果主线程处理完其他的事务后，需要用到子线程的处理结果，也就是主线程需要等待子线程执行完成之后再结束线程和进程，这种情况该怎么处理呢？

这就是线程回收函数 `pthread_join`的应用场景了，这个函数是一个阻塞函数，如果子线程还在运行，该函数就会一直阻塞，子线程退出函数解除阻塞进行资源的回收。函数被调用一次，只能回收一个子线程，如果有多个子线程则需要循环进行回收。

### 4.1线程回收函数（对应进程中 waitpid() 函数）

```c
// 这是一个阻塞函数, 由主线程调用，然后就阻塞在这，直到thread子线程退出，然后返回。
// 回收对应的子线程资源
int pthread_join(pthread_t thread, void **retval);
```

- 参数：
  - thread：要被回收的子线程的线程 ID
  - retval：被回收的子线程通过它传出 `pthread_exit`的参数，即要传出的数据。

### 4.2实例

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

struct Test
{
    int num;
    int age;
};
void * mytask(void * arg)
{
    struct Test * pt = (struct Test *)arg;
    pt->num = 1000;
    pt->age = 99;
    for (int i = 0; i < 10; i++)
    {
        printf("子线程：i = %d\n", i);
        if(i == 7)
        {
            pthread_exit(pt); // 直接退出子线程
        }
    }
    printf("子线程TID：%ld\n", pthread_self());

    return NULL;
}
int main()
{
    pthread_t tid;
    struct Test test;
	
    // 子线程用到了主线程的栈空间test，所以主线程必须等子线程退出后再退出
    pthread_create(&tid, NULL, mytask, &test);
    printf("子线程创建成功, 线程TID: %ld\n", tid);
    printf("主线程TID：%ld\n", pthread_self());
    
    void* ptr = NULL;
    // ptr是一个传出参数, 子线程回收资源被存放在此
    // 这个内存地址就是pthread_exit() 参数指向的内存
    // 阻塞等待子线程退出
    pthread_join(tid, &ptr);

    struct Test* tmp = (struct Test*)ptr;
    printf("子线程返回数据: age: %d, num: %d\n", tmp->age, tmp->num);
    printf("子线程资源被成功回收...\n");

    return 0;
}
```

编译执行结果：

```shell
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# gcc my_pthread_create.c -lpthread -o app
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# ./app 
子线程创建成功, 线程TID: 140123287721728
主线程TID：140123287725888
子线程：i = 0
子线程：i = 1
子线程：i = 2
子线程：i = 3
子线程：i = 4
子线程：i = 5
子线程：i = 6
子线程：i = 7
子线程返回数据: age: 99, num: 1000
子线程资源被成功回收...
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# 
```

注意：虽然每个线程都有属于自己的栈区空间，但是位于同一个地址空间的多个线程是可以相互访问对方的栈空间上的数据的。当然，线程创建函数`pthread_create`的参数`arg`也可以是全局变量或者堆存的内存。

## 5、Linux线程分离

有时候，进程中的主线程也有自己的业务处理流程，如果还是让主线程负责子线程的资源回收，调用 `pthread_join`后，只要子线程不退出主线程就会一直被阻塞，主线程就没办法执行自己的业务处理流程了。

这就是线程分离函数`pthread_detach`的应用场景了，调用线程分离函数之后指定的子线程就可以和主线程分离，当子线程退出的时候，其占用的内核资源会被系统的其他进程接管并回收了。线程分离之后在主线程中使用 `pthread_join`是回收不到子线程资源了的。

### 5.1线程分离函数

```c
int pthread_detach(pthread_t thread);
```

- 参数：
  - thread：要与主线程分离的子线程的线程ID。

- 返回值：成功返回0，失败返回错误码。

### 5.2实例

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

void * mytask(void * arg)
{

    for (int i = 0; i < 10; i++)
    {
        printf("子线程：i = %d\n", i);

    }
    printf("子线程TID：%ld\n", pthread_self());

    return NULL;
}
int main()
{
    pthread_t tid;

    pthread_create(&tid, NULL, mytask, NULL);
    printf("子线程创建成功, 线程TID: %ld\n", tid);
    printf("主线程TID：%ld\n", pthread_self());

    // 主线程子线程分离
    pthread_detach(tid);
    
    // 主线程你自己先退出吧，不用管我，我一个“人”很好
    pthread_exit(NULL);

    return 0;
}
```

程序编译运行结果：

```shell
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# gcc my_pthread_create.c -lpthread -o app
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# ./app 
子线程创建成功, 线程TID: 139791846512384
主线程TID：139791846516544
子线程：i = 0
子线程：i = 1
子线程：i = 2
子线程：i = 3
子线程：i = 4
子线程：i = 5
子线程：i = 6
子线程：i = 7
子线程：i = 8
子线程：i = 9
子线程TID：139791846512384
root@iZwz94euuu9omhoocm3l5uZ:~/07_article# 
```

## 6、Linux其它线程函数

### 6.1线程取消函数（对应进程中 kill() 函数）

杀死（取消）线程 其作用。但不会立刻杀死（取消）进程，只有当`thread`进行了一次系统调用（从用户区切换到内核区），才会死掉。

```c
int pthread_cancel(pthread_t thread);
```

- 参数：
  - thread：要杀死（取消）线程的线程ID。

- 返回值：成功返回0，失败返回错误码。

### 6.2线程ID是否相同函数

```c
int pthread_equal(pthread_t t1, pthread_t t2);
```

- 参数：两个要比较的线程ID。

- 返回值：两个线程 ID 相等返回非 0 值，如果不相等返回 0。

## 7、埋个坑

1. 多线程的同步与互斥使用
2. 线程池
3. 高并发
