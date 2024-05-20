#import "template/template.typ" : codeblock, empty_par

= 设备驱动

在Alien系统中，内核主要功能由其他开发者完成。本文介绍的工作在于为其开发设备驱动的隔离域部分。

为了提高安全性，同时也为了满足Alien隔离域的要求，使用了内存安全 @rust 的语言Rust重新实现了系统中的设备驱动，并且在驱动的代码中没有使用被Rust定义为不安全的操作。

Rust中的不安全操作通常是对于直接以`usize`形式展示的内存地址的访问。而这种操作又是驱动程序必不可少的所需操作之一。为了解决这个矛盾，把目光从驱动程序移到了内核TCB上。操作系统内核的开发也不可避免的需要用到不安全操作。为了尽可能的减少漏洞出现的可能性，最大化安全性，Alien只会有一个核心模块TCB使用不安全代码，而内核的其他部分则依赖TCB，（以`trait`的形式）使用它提供的接口。那么驱动程序就可以效仿内核，把所需的不安全操作抽象成若干接口，并要求内核来实现这些接口。这样，只需要保证在内核TCB中的接口实现是符合语义、安全的，就可以提高安全性了。

这样做的主要好处在于，减小了开发者需要人脑考虑的安全隐患范围。当整个程序都是内存不安全的语言所写时，开发者需要自行确保其代码的安全性。而人脑是难以避免纰漏的。通过把大部分内存安全的检测工作交给Rust的编译器来完成，可以极大减少这种人脑产生的纰漏。

工作内容集中体现在，如何把驱动程序所需的所有不安全操作抽象为尽可能少的接口。在这些接口之上，依赖它们使用完全安全的Rust编程语言完成驱动程序应有功能的开发。以及在这个过程中，如何保持性能不衰减。对于这些问题，分别使用了对于头文件的交互接口、虚拟队列的交互接口来进行抽象和封装；使用传递引用和提供不同层次的API来满足使用者对高性能的需求。

== VirtIO驱动

VirtIO设备 @virtio 是一种专门为虚拟环境设计的虚拟设备。Alien现阶段在qemu模拟器中运行，因此适配了一些qemu提供的VirtIO设备。包括网卡、输入设备（鼠标、键盘、触摸板等）、块设备（硬盘等）、显示设备、控制台设备。

=== 与系统的交互

VirtIO驱动扮演一个桥梁的角色：它与设备交互，接受设备传来的信息并向设备下达指令；同时它也需要与系统交互，把设备输入传给系统，同时接受系统想要对设备进行的操作。

在驱动与系统的交互中，总共需要两种类型的接口，分别是：（1）TCB向驱动提供的功能，即驱动需要依赖系统的部分。这部分接口允许驱动直接读写某块内存区域，或者获得位于特定内存位置处的数据结构，进行物理、虚拟地址转换等需要操作系统内核帮助才能完成的功能。（2）驱动向系统提供的功能。这部分接口运行系统通过驱动对设备进行操作，包括构建驱动进程、对设备进行设置、操作等。

==== 对系统的依赖

为了做到能独立编译，系统向驱动提供依赖的形式以Rust编程中常见的`trait`来完成。具体地说，系统在尝试创建一个驱动对象时，需要调用其构造函数`new()`，而这个函数最终则要求传入一个具有某种所需`trait`的对象（`Box<dyn VirtIoDeviceIo>`）作为参数。因此驱动的使用者需要编写一个结构体，并为其实现`VirtIoDeviceIo`。

这个`trait`所要求的功能是对一段固定的内存进行读写操作，而这段内存将会被操作系统以某种方式映射到设备地址空间（mmio），即与设备的寄存器相对应。对这段内存的操作就相当于对设备进行操作。

同时，构建驱动结构体的时候，还需要传入一个结构作为驱动所需的泛型类型。该结构需要实现`Hal` `trait`，这是为了创建虚拟队列，让驱动能够通过虚拟队列与设备交互。虚拟队列相关内容将在3.1.2描述。通过`Hal`，驱动能够要求操作系统内核为其分配一段连续的内存页来放置虚拟队列，并且在正确的地址从从`usize`形式的位置开始构建出队列，并传给驱动使用。

==== 向系统提供的功能

各驱动根据所对应的设备不同，将会为系统提供不同的功能。如块设备就会提供在特定的块进行读和写的功能。此外，所有驱动都会有创建自身和对设备进行设置（如是否接受中断）的功能。

因为驱动的形式是一个结构体，所以提供功能的形式就是公开的方法。使用者可以直接调用驱动结构体所拥有的方法来完成功能。

每个驱动各自拥有的功能将在各自的章节详细描述。

=== 与设备的交互

驱动与VirtIO设备的交互通过一段被映射的内存和若干个虚拟队列进行。这些结构都由VirtIO的常见组织规定，并且在其文档中描述。

==== 内存映射（MMIO）设备寄存器

VirtIO设备支持两种与操作系统的交互方式：通过PCI总线交互与通过虚拟内存映射交互（MMIO）。Alien中采用了后一种，即把真实的寄存器区域应映射到一段内存中。被映射的内存将会连接到设备地址空间，在这里进行的操作相当于对设备寄存器进行操作。这部分由操作系统完成。

所有VirtIO设备的地址空间首先会有一个长度为256字节的结构，被命名为`VirtIOHeader`。这个结构中有些寄存器是只读的，有些寄存器是只写的，还有一些是可读可写的。这个结构的作用包括让系统认识到这个设备的类型、使用协议版本、支持的特性、支持的队列数量、设备容量等信息，同时允许系统向设备进行通信，来商定启用的特性、队列数量、队列地址等。这个结构是所有VirtIO系列的虚拟设备都会拥有的，其结构也完全相同，是驱动设置区域中通用的一部分。

在`VirtIOHeader`之后，是每种设备不同的设置区域。这段区域的作用是对各设备特有的属性进行设置、通信、协商。它的长度和布局并不统一。

此两处区域主要用于对设备进行初始化和设置。在系统认知到虚拟设备后，就将创建其驱动。而任何一个VirtIO设备的驱动都需要首先对该区域进行设置，以满足设备的使用需求。该区域的头4个字节是表明该处地址段是一个VirtIO虚拟设备的映射空间的标识符，又被称为魔数。其值必须为0x74726976，是小端序下对于字符串`"virt"`的编码。驱动只有在认知到这个数之后，才可以把该内存区域当作一个VirtIO虚拟设备的设置区域的映射来处理，否则驱动应该拒绝对其执行初始化操作。

在实际使用中，寄存器的布局被使用常量泛型的方法硬编码在了程序中。驱动程序不能直接执行这些不安全操作，因此需要操作系统向驱动提供一个有`VirtIoDeviceIo` `trait`的结构。该结构允许驱动从地址空间的起始处按照某个偏移值对内存进行读写操作。在原有的不安全实现中，此处的做法是预先使用C风格的内存布局定义好一个设置头的结构体，该结构的空间分布与VirtIO设备规定的恰好一致。因此所创建出来的结构可以直接对想要执行操作的部位进行读写操作。对于其中的每一个寄存器，它都使用了一个读写权限的包装结构，用于限制失误导致的对其的非正确访问，如尝试读取一个只写寄存器，或尝试写入一个只读寄存器。被安全化后的驱动中，设置头也有一个结构，但是该结构并没有实际的内存布局，而是以常量泛型的方式记录了每个寄存器的位置对于设置头开头地址的偏移量。该常量泛型会存放在事先定义的读写权限包装结构中。由于常量在Rust编译期间会直接被解析并生成为访问正确位置的机器码，因此此方案没有额外的运行时开销。在知道了寄存器相对于设备空间起始位置的偏移量之后，读写权限包装结构所含有的泛型读写函数会使用拥有的常数泛型参数作为向系统申请对特定内存区域进行读写操作时传入的参数。实际被生成出来的代码类似于在函数调用时使用起始地址加偏移量的直接硬编码调用。

至此，完成了对于设置头部分的读写封装，而所需要的接口仅要4个：对某一内存区域特定偏移量分别进行32位无符号整形、8位无符号整形的读取和写入。由于目前Rust还不允许把含有泛型的函数放在trait中作为参数或返回值被动态在函数调用中传递，因此只能使用固定的类型，产生了8位和32位两种规格但实质相同的接口。如果只使用8位无符号整形进行读写也可以完成全部功能，但是这会导致32位或64位无符号整形的读写需要被对应拆成4个或8个读写操作，大大减慢了操作速度，因此加入了32位无符号整形以保证速度。

至于各设备各有的设置区域，对其的读写结构封装与设置头大体一致。但是由于设置头中储存数据的类型只有32位无符号整形，但是在各设备区域中需要的类型多种多样，从8位无符号整形到64位，还有一些设备需要读写数组，因此对于读写权限结构中内含的数据类型使用了泛型。并对各个可能出现的具体类型需要分别实现不同的读写函数以把读写操作正确地转换为对系统的函数调用。目前需要对共4种类型的3种读写权限全部进行实现，该部分代码冗余较多而重复性较强，可以使用宏实现。

借由此封装，驱动可以安全的对设备的地址空间进行读写操作而只使用到了安全代码，无需担心对内存地址可能的混淆带来的负面后果。操作系统将要负责检查驱动调用函数时传入的参数是否合法，随后才进行不安全代码的执行。需要被注意的风险面就缩小到了仅仅需要被提供的4个函数中。

==== 虚拟队列

一个设备可以拥有一个或多个虚拟队列（VirtQueue），虚拟队列的作用是允许驱动向设备发送具体的操作请求，并从设备处接受操作后的结果。一个虚拟队列是唯一一段连续物理页上的三个数据结构，分别是描述符表（Descripter table），可用环（Avail Ring），已用环（Used Ring）。其中描述符表是由若干个描述符（Descripter）组成的数组，而每个描述符内含指向一段内存区域的指针、该区域的长度和该区域的属性（设备是否可读写、是否还有下一个描述符，下一个描述符的下标）。每个驱动对设备的操作请求的形式都会是一个描述符组成的链。而具体是什么类型的操作、操作所需的传入参数、所需的放置结果的内存地址，都会放在描述符所指向的区域中。可用环和已用环则是两个使用数组实现的队列，其中分别存放需要设备完成的操作和设备已完成的操作。每个操作都占据数组中恰好一个位置，表现形式是该操作的描述符链的首个节点在描述符表中的下标。

每个虚拟队列的长度都可以由驱动规定，但是不能超过设备所能处理的长度上限。该长度上限存在于设备的设置头中，可以被驱动读取和确认。当驱动准备好想要设置的虚拟队列长度之后，可以通过向设备的设置头中的一个寄存器中先写入想要设置的队列序号，此时设备将会知道现在要处理的是该虚拟队列，随后在另一个寄存器中写入队列长度来通知设备该队列的长度是多少。通过切换队列序号，可以为多个队列用此种方法设置长度。比如网卡设备就可以拥有多个虚拟队列，最少需要两个，分别是接受数据包所用的和发送数据包所用的。

===== 内存布局

由于VirtIO设备规定虚拟队列内的三个结构必须按照特定的偏移布局放置在内存中，因此不能直接使用语言和系统自带的内存分配方法。具体来说，VirtIO要求每个虚拟队列都被分配在一段连续内存物理页上。

对于每个虚拟队列，其中的描述符表将要被放置在该段内存的起始处。描述符表的总长度计算公式为 $"len"(italic("Desc Table")) = 16 dot italic("Queue Size")$，单位是字节。其中每个描述符长度为16个字节，分别由一个8字节的地址，4字节的长度，2字节的标识和2字节的下一个描述符索引构成。描述符表中所有的描述符顺序放置，并不再有其他任何成员。而描述符的个数也就是虚拟队列的长度。因此描述符表的长度就是虚拟队列的长度乘以单个描述符的大小。

在描述符表之后，紧挨着放置可用环。可用环的长度计算公式是$"len"(italic("Avail Ring")) = 2 dot italic("Queue Size") + 6$，单位也是字节。可用环由三个16位无符号整形和一个长度等于队列长度的16位无符号整形数组构成。其中三个单独的位置所存放的分别是标识、驱动下一个将要向可用环中写入的下标序号和设备已经承认的驱动发出的请求的下标序号。

在这两个结构都于内存中放置完成之后，将他们一起按照内存页对齐。对齐后的下一个结构的开始地址就成了一个新完整内存页的起始处。通常内存页的大小是4096字节，但是这并不绝对，依赖于交互方式（`Transport`）。通过向设备设置头中的一个寄存器中写入队列对齐大小，驱动可以通知设备系统所采用的对齐页大小是多少。在这新的一页开头处放置已用环。已用环的大小与可用环的大小计算方法类似，公式为$"len"(italic("Used Ring")) = 8 dot italic("Queue Size") + 6$，单位也是字节。其中单独的6个字节所存放数据与可用环相似，区别仅在于已用环中的数据全部是描述设备已经往其中写入的设备完成的请求，而不是驱动发起的设备需要完成的请求。队列长度之前的系数从2变成了8，这是因为在已用环的数组中，储存的数据长度从2字节变为了8字节。

因此，一个虚拟队列所需要的空间至少为2个地址连续的物理页，准确的大小计算公式为：
$ "len"(italic("Virt Queue")) = limits("align")_"page size" ("len"(italic("Desc Table")) + "len"(italic("Avail Ring"))) + "len"(italic("Used Ring")) \ #h(2em) = limits("align")_"page size" (18 dot italic("Queue Size") + 6) + 8 dot italic("Queue Size") + 6 $ <qlen>

#empty_par

直接操控内存地址，在特定的位置构建出结构是不安全的。因此，这部分也被移动到了系统TCB中完成。具体的方法如 @qapi 所示，系统将会为驱动提供两个接口：（1）第一个接口允许驱动要求系统按照虚拟队列的内存布局为其分配若干个物理地址连续的内存页，并从该处内存上创建出虚拟队列的结构来。驱动需要自行计算出三个结构分别所在的偏移量，并通过`QueueLayout`传递给系统。接口会返回一个`QueuePage<SIZE>`结构。通过该结构驱动可以直接获取虚拟队列的可变引用，以直接访问该地址处的内存；（2）第二个接口是实现了`QueuePage` `trait`的结构体需要实现的一个方法，它允许驱动获得最终被使用的虚拟队列结构。

#codeblock(
  ```rust
  pub trait QueuePage<const SIZE: usize>: DevicePage {
    fn queue_ref_mut(&mut self, layout: &QueueLayout) -> QueueMutRef<SIZE>;
  }
  fn dma_alloc(pages: usize) -> Box<dyn QueuePage<SIZE>>;
  ```,
  caption: "虚拟队列接口", outline: true
) <qapi>


这种方式虽然实现了目标需求，但是由于它把虚拟队列内部的结构暴露给了使用者，要求使用者进行配合，因此并非完美。还存在另一种可行方案：对于虚拟队列采用与寄存器映射相同的读写方式，只需提供对特定偏移处的读写功能即可。这种方案需要更多的工作，并且需要操作系统提供的接口数量更多，但是不用把虚拟队列的内部结构暴露给使用者。目前没有选择实现这种方案。

如果把泛型常数用于分配空间的计算中，则可以做到既不向系统暴露具体的虚拟队列内部结构细节，又能够把需要系统提供的接口控制在最小的范围内。但是非常令人遗憾的是Rust语言目前并不支持泛型常数参与运算。如果之后的更新能够为Rust语言带来这个新特性，那么此处对于虚拟队列空间申请的接口将可以以更优雅的方式实现。

===== 描述符表

在虚拟队列被构建出来之后，驱动程序还需要向设置头中写入虚拟队列的相关信息，包括虚拟队列的长度，所启用的特性与所处的物理地址。这是虚拟队列初始化的过程，同时也是对设备初始化中的一环。由于设备与内存设备之间的通信并不通过操作系统，而是直接经过DMA总线发送请求，因此操作系统所准备的虚拟地址空间和页表也全部失效。向设备写入的队列地址和请求地址全部都需要是物理地址。鉴于此操作系统还需要为驱动提供一个功能，即把一个虚拟地址转换为物理地址，并允许设备对该地址的访问。

初始化完成之后，驱动就可以使用虚拟队列向设备发送请求，同时设备也可以使用该队列响应请求了。VirtIO设备的事件逻辑是所有请求都由驱动主动发起，随后由设备响应。因此一次完整的请求流程是：驱动首先在内存中分配出一段空间，向其中填入各个设备所独有的各不相同的请求结构。随后在描述符表中获取一个空闲的描述符，把新分配的该描述符的物理地址通过系统提供的接口转换虚拟地址得到并填入，再写入该描述符的长度。如果驱动想要设备进行的操作需要额外的空间，则还需要更多的描述符参与该次请求。这种情况下所有参与的描述符会形成一个链表结构。如果一个描述符的下一个节点标识被设置为1，则描述符中指向下一个描述符在描述符表中下标的变量将有意义，设备会依据此不断找到之后的所分配的内存空间。由于分配内存是操作系统层面的工作，设备无法直接分配内存，为了保护内存，设备只会修改在描述符中指向的确定长度的内存。因此，在发出请求分配内存时，就需要事先将设备将会返回给驱动的响应所存放的空间也提前准备好，并放入某个描述符链上的节点所指向的空间处。最后，对于需要返回一个操作状态的设备来说，还需要一块空间用于存放设备对操作的完成情况，它一般作为描述符表链中的最后一个元素出现。

===== 可用环

可用环是只允许驱动写入、设备读取的数据结构。它的功能是为驱动提供通知设备每个请求的描述符链的起始节点位于描述符表中下标位置的手段。借由此结构，驱动为设备指出它所需要完成的请求存放在哪里。而设备则可以从其中读取到所需的信息。

当驱动收到一个请求时，它首先构造好描述符链，随后把链头节点所在描述符表中的下标写入可用环中的下一个可用位置，并根据特性协商情况判断是否发送中断通知设备。

===== 已用环

已用环的作用与可用环恰好相反。它只允许设备写入，驱动读取。设备通过这个数据结构通知驱动它所完成的请求的描述符链的起始节点位于描述符表中的哪里。

当设备完成一个驱动通过已用环通知它的请求后，它就会把所完成的那个请求的描述符链链头节点下标写入已用环中的下一个可用位置，并根据特性协商情况判断是否发送中断通知驱动。

#figure(
  image("image/vq.drawio.svg"),
  caption: "虚拟队列结构"
) <vq_struct>

如 @vq_struct ，该图展示了一个可能出现的场景：一个块设备驱动向设备发出了两个请求，分别是：（1）对某一块的读取，因此共需要三个描述符，中间的请求内容是一块用于给设备写入读取结果的缓冲区。该请求的描述符链是$1 #sym.arrow.r 2 #sym.arrow.r 6$。（2）对某一块的擦除操作，因此共需要两个描述符。描述符链是$4 #sym.arrow.r 9$。图中蓝色箭头是驱动所需要进行的联系（赋值）操作。随后设备先完成了请求（2），并把该请求的链头下标4放入已用环中的第一个位置，随后完成了请求（1）并放入已用环的第二个位置。驱动会把两个请求的执行结果分别相对写入描述符表中9和4位置所指向的响应内存处。请求和响应的格式都在VirtIO的文档中有所规定。如果特性没有协商，设备默认不保证按请求给出的时间顺序进行响应。因此这两个任务的完成顺序可能与给出顺序相反。红色箭头是驱动需要进行的联系（赋值）操作。

=== 块设备

块设备是一种用于持久储存数据的IO设备，包括硬盘、SD卡、U盘等。这种设备提供的最小读写单位是块，因此被称为块设备。对块设备可以进行的操作共有8种。每种操作都需要在描述符所指向的地址处放置一个Request结构。其中描述了操作的类型、目标块标号和数据存放缓冲区。注意这个结构可以被分开放置于多个描述符指向的地址中。在实际使用中，需要操作的元数据（操作类型、块标号）被放在首个描述符指向的区域中，并把读写操作所需的缓冲区放置在第二个描述符指向的区域中。设备在完成操作后会向驱动返回一个状态值，它将被存放在缓冲区之后的第三个（非读写操作则是第二个）描述符指向的区域中。

块设备的特点是对它的操作是由系统发出、设备接受的。这与VirtIO所设计的操作通信模式一致，因此较容易实现。

驱动提供了阻塞式和非阻塞式的接口，使用者可以任选一种使用。非阻塞式是基础的操作方式，也是VirtIO设备运行的模式。驱动在发出操作请求之后，可以不时进行查询操作是否完成。如果完成，则接受操作的结果。此外，如果中断特性被协商开启，那么设备在完成操作之后也会发出一个中断来通知系统。

=== 输入设备

输入设备是用于接受用户外部输入的设备，包括鼠标、键盘、触摸板等。输入设备的操作类型非常简单，只有一种，就是驱动从设备处接受一个输入事件。这个事件将会含有一些属性，如输入类型（触发了哪个按键），鼠标移动的距离，等。通信方式是驱动向设备发出一个请求，而当输入设备接受到一个新的用户输入时，就把输入写入到请求中的储存区域，然后返回给驱动。

输入设备与之后的网卡，这两个设备与块设备之间有一点不同，就是它们需要处理的事件会包含从设备处发出而系统接受的类型。这种类型与VirtIO设备的操作通信模式相异，因此需要一些额外的处理。被选中的解决方案是，从驱动初始化的时候开始，就保持可用环（即驱动向设备发出的请求）始终为满。因此，每当设备接受到一个输入时，总是有可用的请求用于存放输入并返回给驱动（可用请求总数为队列大小）。而系统会定期轮询驱动查询有无新的输入。此时驱动会把一个设备已经完成并返回的操作接受，取出其中的输入传给系统，并继续向可用环中插入新的请求。

=== 网卡

网卡是用于通过网络通信（即发送与接受数据包）的设备。驱动在这个过程中要做的事情主要有两件，即收和发数据包。在发送数据包时，驱动从系统处获取想要发送的一个数据包，在其前方加入VirtIO网络包的header，并将其传递给设备处理。在接受数据包时，驱动从设备处获取一个收到的数据包，剥离其开头的VirtIO网络包header，并把内部的内容返回给系统。

网卡与输入设备虽然都有与VirtIO操作通信模式相异的事件，但它们之间还有不同之处，这是因为输入设备需要接受的是可以直接进行逐字节拷贝（即实现了`Copy` `trait`）的基本类型数据，其大小极小（仅64位）使得拷贝过程不会影响性能。但是网卡所接受的内容是一整个数据包，其大小可能达到上千字节。如果逐字节拷贝这个数据，那么对性能的影响将会是不可接受的。因此可行的方案是直接保持数据在内存中的存放位置不懂，仅传递指针。在一些情况下，使用者可能想要自行决定网络收发的数据包需要放在什么地方（如Alien中数据包需要跨域进行传递，因此需要被放置在共享堆上）。另外的情况下使用者可能想要开箱即用而不关心数据包实际上存放在了哪里。因此向使用者提供了两种不同的驱动：`VirtIONet`和`VirtIONetRaw`。从名称上可以看出，后者允许使用者自行为数据包收发分配内存空间，并只需向驱动提供数据包的地址即可；前者则在基础驱动之上进行了更多的封装，提供了直接传入数据包进行发送，接受数据包的功能。当然这会带来一定的性能损失，对性能有追求的使用者应该使用基础的驱动。

== Uart16550驱动

这是一个物理存在的串口设备。与VirtIO系列的设备不同。因此它的驱动也和VirtIO设备的驱动分开成了两份代码。串口设备用于在多个设备间进行字节粒度的数据传输。它的通信模式也更加简单：往其某个寄存器中写入数据即是发送，而从某个寄存器中读取数据即是接受。

与VirtIO设备相同，对寄存器的操作也被归纳成了一个`trait`，提供按字节对一段内存进行读写的能力。该段内存被映射到设备寄存器上。

== 在Alien中的适配

以上的驱动为满足通用性，都完全仅使用Rust库中所定义的结构写成，只依赖了一些在官方仓库中存在的包，而没有依赖任何Alien中的结构。因此保证了该驱动的通用性，能够被多个系统代码级的复用，而不仅限于在Alien中使用。为了在Alien中以隔离域的形式加入这些驱动，还需要对其进行包装，使其满足隔离域的约束，能够于Alien系统进行交互。

为了在Alien中新加入一个隔离域来实现驱动功能，首先需要在Alien中新建一个结构，作为系统的驱动域实体。该结构将会被隔离域传递给系统，系统视此结构为一个驱动程序，而它实际做的工作是在驱动的Rust标准结构和Alien中特有的结构之间提供转化层。该结构将会引用并创建一个经过安全化的标准驱动作为静态对象。系统对设备的操作通过这个结构中介，转发到静态全局变量的驱动中。随后中介结构处理驱动传递回来的结果并返回给系统。当一个Alien特有的结构（如`RRef<T>`）穿越域边界来到中介结构时，它干的第一件工作是取得该参数内部的实际数据，并把拆装后的实际参数传递给自身所拥有的静态实际驱动。驱动返回的结果通常是直接的返回值或者伴随有驱动内定义的错误类型。代理结构把驱动的错误类型映射为Alien系统内的错误类型，如果是存在于共享堆上的数据指针，则还需要用共享堆封装结构`RRef<T>`将其保存，随后用隔离域必须要的返回值类型`RpcResult<T>`将其包装，最后传递回系统。这个过程提供了安全驱动和Alien之间的对接。

与驱动直接使用Alien中的结构进行编写相比，它的缺点是多了一层函数调用，这会带来额外的开销。但是它的好处是可以将驱动程序与Alien完全独立，提高了驱动的通用性。这被认为是非常有意义的工作，可以参与进社区的相互参考、学习、改进过程中，最终推动更优秀的成果出现。因此该方案在驱动与Alien的整合形式的取舍中胜出。同时，实际使用时的情形也表明，由于对驱动的操作性能瓶颈通常不在函数的调用时间，增加的开销几乎无法感知。该方案可以作为很好的驱动与操作系统整合的示例。类似的方案可以被用于多个操作系统中。
