第三章 设备驱动

为了提高安全性，同时也为了满足Alien隔离域的要求，我们使用了内存安全[]的语言Rust重新实现了系统中的设备驱动，并且在驱动的代码中没有使用被Rust定义为不安全的操作[]。
Rust中的不安全操作通常是对于直接以`usize`形式展示的内存地址的访问。而这种操作又是驱动程序必不可少的所需操作之一。为了解决这个矛盾，我们把目光从驱动程序移到了内核TCB上。操作系统内核的开发也不可避免的需要用到不安全操作。为了尽可能的减少漏洞出现的可能性，最大化安全性，Alien只会有一个核心模块TCB使用不安全代码，而内核的其他部分则依赖TCB，（以`trait`的形式）使用它提供的接口。那么驱动程序就可以效仿内核，把所需的不安全操作抽象成若干接口，并要求内核来实现这些接口。这样，只需要保证在内核TCB中的接口实现是符合语义、安全的，就可以提高安全性了。
这样做的主要好处在于，减小了开发者需要人脑考虑的安全隐患范围。当整个程序都是内存不安全的语言所写时，开发者需要自行确保其代码的安全性。而人脑是难以避免纰漏的。通过把大部分内存安全的检测工作交给Rust的编译器来完成，可以极大减少这种人脑产生的纰漏。

3.1 VirtIO驱动

VirtIO设备是一种专门为虚拟环境设计的虚拟设备。Alien现阶段在qemu模拟器中运行，因此我们适配了一些qemu提供的VirtIO设备。包括网卡、输入设备（鼠标、键盘、触摸板等）、块设备（硬盘等）、显示设备、控制台设备。

3.1.1 与系统的交互

VirtIO驱动扮演一个桥梁的角色：它与设备交互，接受设备传来的信息并向设备下达指令；同时它也需要与系统交互，把设备输入传给系统，同时接受系统想要对设备进行的操作。

在驱动与系统的交互中，总共需要两种类型的接口，分别是：（1）TCB向驱动提供的功能，即驱动需要依赖系统的部分。这部分接口允许驱动直接读写某块内存区域，或者获得位于特定内存位置处的数据结构，进行物理、虚拟地址转换等需要操作系统内核帮助才能完成的功能。（2）驱动向系统提供的功能。这部分接口运行系统通过驱动对设备进行操作，包括构建驱动进程、对设备进行设置、操作等。

3.1.1.1 对系统的依赖

为了做到能独立编译，系统向驱动提供依赖的形式以Rust编程中常见的`trait`来完成。具体地说，系统在尝试创建一个驱动对象时，需要调用其构造函数`new()`，而这个函数最终则要求传入一个具有我们要求的某种`trait`的对象（`Box<dyn VirtIoDeviceIo>`）作为参数。因此驱动的使用者需要编写一个结构体，并为其实现`VirtIoDeviceIo`。
这个`trait`所要求的功能是对一段固定的内存进行读写操作，而这段内存将会被操作系统以某种方式映射到设备地址空间（mmio或者plic），即与设备的寄存器相对应。对这段内存的操作就相当于对设备进行操作。

同时，构建驱动结构体的时候，还需要传入一个结构作为驱动所需的泛型类型。该结构需要实现`Hal` `trait`，这是为了创建虚拟队列，让驱动能够通过虚拟队列与设备交互。虚拟队列相关内容将在3.1.2描述。通过`Hal`，驱动能够要求操作系统内核为其分配一段连续的内存页来放置虚拟队列，并且在正确的地址从从`usize`形式的位置开始构建出队列，并传给驱动使用。

3.1.1.2 向系统提供的功能

各驱动根据所对应的设备不同，将会为系统提供不同的功能。如块设备就会提供在特定的块进行读和写的功能。此外，所有驱动都会有创建自身和对设备进行设置（如是否接受中断）的功能。
因为驱动的形式是一个结构体，所以提供功能的形式就是公开的方法。使用者可以直接调用驱动结构体所拥有的方法来完成功能。
每个驱动各自拥有的功能将在各自的章节详细描述。

3.1.2 与设备的交互
驱动与VirtIO设备的交互通过一段被映射的内存和若干个虚拟队列进行。这些结构都由VirtIO的常见组织规定，并且在其文档[]中描述。

3.1.2.1 内存映射（MMIO）设备寄存器

被映射的内存将会连接到设备地址空间，在这里进行的操作相当于对设备寄存器进行操作。所有VirtIO设备的地址空间首先会有一个长度为256字节的结构，被命名为`VirtIOHeader`。这个结构中有些寄存器是只读的，有些寄存器是只写的，还有一些是可读可写的。这个结构的作用包括让系统认识到这个设备的类型、使用协议版本、支持的特性、支持的队列数量、设备容量等信息，同时允许系统向设备进行通信，来商定启用的特性、队列数量、队列地址等。
在`VirtIOHeader`之后，是每种设备不同的设置区域。这段区域的作用是对各设备特有的属性进行设置、通信、协商。它的长度和布局并不统一。

在实际使用中，我们把寄存器的布局使用常量泛型的方法硬编码在了程序中。驱动程序不能直接执行这些不安全操作，因此需要操作系统向我们提供一个有`VirtIoDeviceIo` `trait`的结构。该结构允许驱动从地址空间的起始处按照某个偏移值对内存进行读写操作。

3.1.2.2 虚拟队列

一个设备可以拥有一个或多个虚拟队列（VirtQueue），虚拟队列的作用是允许驱动向设备发送具体的操作请求，并从设备处接受操作后的结果。一个虚拟队列是唯一一段连续物理页上的三个数据结构，分别是描述符表（Descripter table），可用环（Avail Ring），已用环（Used Ring）。其中描述符表是由若干个描述符（Descripter）组成的数组，而每个描述符内含指向一段内存区域的指针、该区域的长度和该区域的属性（设备是否可读写、是否还有下一个描述符，下一个描述符的下标）。每个驱动对设备的操作请求的形式都会是一个描述符组成的链。而具体是什么类型的操作、操作所需的传入参数、所需的放置结果的内存地址，都会放在描述符所指向的区域中。可用环和已用环则是两个使用数组实现的队列，其中分别存放需要设备完成的操作和设备已完成的操作。每个操作都占据数组中恰好一个位置，表现形式是该操作的描述符链的首个节点在描述符表中的下标。

由于VirtIO设备规定虚拟队列内的三个结构必须按照特定的偏移布局放置在内存中，因此我们不能直接使用语言和系统自带的内存分配方法。同时，直接操控内存地址，在特定的位置构建出结构也是不安全的。因此，这部分也被移动到了系统TCB中完成。具体的方法是：系统将会为驱动提供两个接口，第一个允许驱动要求系统为其分配若干个物理地址连续的内存页，第二个允许驱动要求系统按照某种给定的布局方式在内存特定位置处构建出队列内的三个结构，并把构建成果返回给驱动使用。

这种方式虽然实现了我们的需求，但是由于它把虚拟队列内部的结构暴露给了使用者，要求使用者进行配合，因此并非完美。我们还提出了另一种方案：对于虚拟队列采用与寄存器映射相同的读写方式，只需提供对特定偏移处的读写功能即可。这种方案需要更多的工作，并且需要操作系统提供的接口数量更多，但是不用把虚拟队列的内部结构暴露给使用者。目前我们没有选择实现这种方案。

3.1.3 块设备

块设备是一种用于持久储存数据的IO设备，包括硬盘、SD卡、U盘等。这种设备提供的最小读写单位是块，因此被称为块设备。对块设备可以进行的操作共有8种。每种操作都需要在描述符所指向的地址处放置一个Request结构。其中描述了操作的类型、目标块标号和数据存放缓冲区。注意这个结构可以被分开放置于多个描述符指向的地址中。在实际使用中，我们把操作的元数据（操作类型、块标号）放在首个描述符指向的区域中，并把读写操作所需的缓冲区放置在第二个描述符指向的区域中。设备在完成操作后会向驱动返回一个状态值，它将被存放在缓冲区之后的第三个（非读写操作则是第二个）描述符指向的区域中。

块设备的特点是对它的操作是由系统发出、设备接受的。这与VirtIO所设计的操作通信模式一致，因此较容易实现。
我们的驱动提供了阻塞式和非阻塞式的接口，使用者可以任选一种使用。非阻塞式是基础的操作方式，也是VirtIO设备运行的模式。驱动在发出操作请求之后，可以不时进行查询操作是否完成。如果完成，则接受操作的结果。此外，如果中断特性被协商开启，那么设备在完成操作之后也会发出一个中断来通知系统。

3.1.4 输入设备

输入设备是用于接受用户外部输入的设备，包括鼠标、键盘、触摸板等。输入设备的操作类型非常简单，只有一种，就是驱动从设备处接受一个输入事件。这个事件将会含有一些属性，如输入类型（触发了哪个按键），鼠标移动的距离，等。通信方式是驱动向设备发出一个请求，而当输入设备接受到一个新的用户输入时，就把输入写入到请求中的储存区域，然后返回给驱动。

输入设备与之后的网卡，这两个设备与块设备之间有一点不同，就是它们需要处理的事件会包含从设备处发出而系统接受的类型。这种类型与VirtIO设备的操作通信模式相异，因此需要一些额外的处理。我们选择的方式是，从驱动初始化的时候开始，就保持可用环（即驱动向设备发出的请求）始终为满。因此，每当设备接受到一个输入时，总是有可用的请求用于存放输入并返回给驱动（可用请求总数为队列大小）。而系统会定期轮询驱动查询有无新的输入。此时驱动会把一个设备已经完成并返回的操作接受，取出其中的输入传给系统，并继续向可用环中插入新的请求。

3.1.5 网卡

网卡是用于通过网络通信（即发送与接受数据包）的设备。驱动在这个过程中要做的事情主要有两件，即收和发数据包。在发送数据包时，驱动从系统处获取想要发送的一个数据包，在其前方加入VirtIO网络包的header，并将其传递给设备处理。在接受数据包时，驱动从设备处获取一个收到的数据包，剥离其开头的VirtIO网络包header，并把内部的内容返回给系统。

网卡与输入设备虽然都有与VirtIO操作通信模式相异的事件，但它们之间还有不同之处，这是因为输入设备需要接受的是可以直接进行逐字节拷贝（即实现了`Copy` `trait`）的基本类型数据，其大小极小（仅64位）使得拷贝过程不会影响性能。但是网卡所接受的内容是一整个数据包，其大小可能达到上千字节。如果逐字节拷贝这个数据，那么对性能的影响将会是不可接受的。因此可行的方案是直接保持数据在内存中的存放位置不懂，仅传递指针。在一些情况下，使用者可能想要自行决定网络收发的数据包需要放在什么地方（如Alien中数据包需要跨域进行传递，因此需要被放置在共享堆上）。另外的情况下使用者可能想要开箱即用而不关心数据包实际上存放在了哪里。因此我们提供了两种不同的驱动：`VirtIONet`和`VirtIONetRaw`。从名称上可以看出，后者允许使用者自行为数据包收发分配内存空间，并只需向驱动提供数据包的地址即可；前者则在基础驱动之上进行了更多的封装，提供了直接传入数据包进行发送，接受数据包的功能。当然这会带来一定的性能损失，对性能有追求的使用者应该使用基础的驱动。

3.2 Uart16550驱动

这是一个物理存在的串口设备。与VirtIO系列的设备不同。因此它的驱动也和VirtIO设备的驱动分开成了两份代码。串口设备用于在多个设备间进行字节粒度的数据传输。它的通信模式也更加简单：往其某个寄存器中写入数据即是发送，而从某个寄存器中读取数据即是接受。

与VirtIO设备相同，对寄存器的操作也被归纳成了一个`trait`，提供按字节对一段内存进行读写的能力。该段内存被映射到设备寄存器上。

3.3 在Alien中的适配

以上的驱动为满足通用性，都完全仅使用Rust库中所定义的结构写成，能够被多个系统使用。为了在Alien中以隔离域的形式加入这些驱动，还需要使其满足隔离域的约束。

对此我们的做法是在Alien中新建一个结构，作为系统的驱动域实体。而这个域将会引用并创建一个经过安全化的标准驱动作为静态对象。系统对设备的操作通过域这个中介，转发到静态全局变量的驱动中。而对于域结构体，实现域所需要的满足的接口和约束。