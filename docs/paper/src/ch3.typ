#import "template/template.typ" : empty_par

= 驱动实现

== VirtIO驱动

VirtIO设备 @virtio 是一种专门为虚拟环境设计的虚拟设备。Alien现阶段在qemu模拟器中运行，因此适配了一些qemu提供的VirtIO设备。包括网卡、输入设备（鼠标、键盘、触摸板等）、块设备（硬盘等）、显示设备、控制台设备。

=== 块设备

块设备是一种用于持久储存数据的IO设备，包括硬盘、SD卡、U盘等。这种设备提供的最小读写单位是块，因此被称为块设备。对块设备可以进行的操作共有8种。每种操作都需要在描述符所指向的地址处放置一个Request结构。其中描述了操作的类型、目标块标号和数据存放缓冲区。注意这个结构可以被分开放置于多个描述符指向的地址中。在实际使用中，需要操作的元数据（操作类型、块标号）被放在首个描述符指向的区域中，并把读写操作所需的缓冲区放置在第二个描述符指向的区域中。设备在完成操作后会向驱动返回一个状态值，它将被存放在缓冲区之后的第三个（非读写操作则是第二个）描述符指向的区域中。

块设备支持的特性位展示在下表中：

#figure(
  table(
    columns: 2,
    inset: (x: 1em),
    [位],[名称],
    [0],[VIRTIO_BLK_F_BARRIER],
    [1],[VIRTIO_BLK_F_SIZE_MAX],
    [2],[VIRTIO_BLK_F_SEG_MAX],
    [4],[VIRTIO_BLK_F_GEOMETRY],
    [5],[VIRTIO_BLK_F_RO],
    [6],[VIRTIO_BLK_F_BLK_SIZE],
    [7],[VIRTIO_BLK_F_SCSI],
    [9],[VIRTIO_BLK_F_FLUSH],
    [10],[VIRTIO_BLK_F_TOPOLOGY],
    [11],[VIRTIO_BLK_F_CONFIG_WCE],
    [13],[VIRTIO_BLK_F_DISCARD],
    [14],[VIRTIO_BLK_F_WRITE_ZEROES],
  ),
  caption: [块设备特性位],
)

它有一个称为`requestq`的虚拟队列，用于执行所有操作。块设备的大小固定以512字节为一个块。初始化时，需要按如下步骤对块设备进行操作：

1. 从设备处阅读总容量。
2. 如果`VIRTIO_BLK_F_BLK_SIZE`特性被协商启用，驱动可以读取到`blk_size`，用以作为最优的设备块大小。这并不影响协议中的单位大小，它总是512位。只是一个影响性能的因素。
3. 检测是否启用了`VIRTIO_BLK_F_RO`特性。如果启用，则对设备的所有写操作将会被拒绝。
4. 检测是否启用了`VIRTIO_BLK_F_TOPOLOGY`特性。如果启用了，则`topology`结构中的字段可以被读取，以决定最优的读写操作物理块长度。这也只影响性能而不影响协议。
5. 如果`VIRTIO_BLK_F_CONFIG_WCE`特性被启用，则可以通过`writeback`字段读取或设置缓存模式。设为`0`表示通写(Writethrough)模式，设为`1`表示写回(Writeback)模式。在设备重置之后，缓存模式可能是以上两种中任一种。在特性协商之后，可以读取该字段来判断到底时哪一种。
6. 如果`VIRTIO_BLK_F_DISCARD`特性被启用，`max_discard_sectors`和`max_discard_seg`字段可以被读取，用于决定块设备用的最大折扣区和最大折扣段编号。当操作系统基于对齐进行操作时，可以使用`discard_sector_alignment`字段。
7. 如果`VIRTIO_BLK_F_WRITE_ZEROES`特性被启用，`max_write_zeroes_sectors`和`max_write_zeroes_seg`字段可以被读取，用于决定块设备驱动使用的最大写入0区和最大写入0段的编号。

当驱动不会发出flush请求时，它不应该协商`VIRTIO_BLK_F_FLUSH`特性。

块设备的特点是对它的操作是由系统发出、设备接受的。这与VirtIO所设计的操作通信模式一致，因此较容易实现。

驱动提供了阻塞式和非阻塞式的接口，使用者可以任选一种使用。非阻塞式是基础的操作方式，也是VirtIO设备运行的模式。驱动在发出操作请求之后，可以不时进行查询操作是否完成。如果完成，则接受操作的结果。此外，如果中断特性被协商开启，那么设备在完成操作之后也会发出一个中断来通知系统。

=== 输入设备

输入设备是用于接受用户外部输入的设备，包括鼠标、键盘、触摸板等。输入设备的操作类型非常简单，只有一种，就是驱动从设备处接受一个输入事件。这个事件将会含有一些属性，如输入类型（触发了哪个按键），鼠标移动的距离，等。通信方式是驱动向设备发出一个请求，而当输入设备接受到一个新的用户输入时，就把输入写入到请求中的储存区域，然后返回给驱动。

输入设备无任何支持的特性。

输入设备与之后的网卡，这两个设备与块设备之间有一点不同，就是它们需要处理的事件会包含从设备处发出而系统接受的类型。这种类型与VirtIO设备的操作通信模式相异，因此需要一些额外的处理。被选中的解决方案是，从驱动初始化的时候开始，就保持可用环（即驱动向设备发出的请求）始终为满。因此，每当设备接受到一个输入时，总是有可用的请求用于存放输入并返回给驱动（可用请求总数为队列大小）。而系统会定期轮询驱动查询有无新的输入。此时驱动会把一个设备已经完成并返回的操作接受，取出其中的输入传给系统，并继续向可用环中插入新的请求。

=== 网卡

网卡是用于通过网络通信（即发送与接受数据包）的设备。驱动在这个过程中要做的事情主要有两件，即收和发数据包。在发送数据包时，驱动从系统处获取想要发送的一个数据包，在其前方加入VirtIO网络包的header，并将其传递给设备处理。在接受数据包时，驱动从设备处获取一个收到的数据包，剥离其开头的VirtIO网络包header，并把内部的内容返回给系统。

网卡设备可以有$2n+1 ( n in NN_+)$个虚拟队列。编号依次为$0, 1, ..., 2n$。其中前$n$个偶数编号的队列为接受队列，前$n$个奇数编号的队列为发送队列。第$2n$个队列为控制队列。如果`VIRTIO_NET_F_MQ`特性未被协商，则$n=1$。否则$n$由`max_virtqueue_pairs`设定。只有当特性`VIRTIO_NET_F_CTRL_VQ`启用时才存在控制队列。

网课设备的特性位如下表所示：

#figure(
  table(
    columns: 2,
    inset: (x: 1em),
    [位],[名称],
    [0],[VIRTIO_NET_F_CSUM ],
    [1],[VIRTIO_NET_F_GUEST_CSUM ],
    [2],[VIRTIO_NET_F_CTRL_GUEST_OFFLOADS],
    [3],[VIRTIO_NET_F_MTU],
    [5],[VIRTIO_NET_F_MAC ],
    [6],[VIRTIO_NET_F_GSO ],
    [7],[VIRTIO_NET_F_GUEST_TSO4 ],
    [8],[VIRTIO_NET_F_GUEST_TSO6 ],
    [9],[VIRTIO_NET_F_GUEST_ECN ],
    [10],[VIRTIO_NET_F_GUEST_UFO ],
    [11],[VIRTIO_NET_F_HOST_TSO4 ],
    [12],[VIRTIO_NET_F_HOST_TSO6 ],
    [13],[VIRTIO_NET_F_HOST_ECN ],
    [14],[VIRTIO_NET_F_HOST_UFO ],
    [15],[VIRTIO_NET_F_MRG_RXBUF ],
    [16],[VIRTIO_NET_F_STATUS ],
    [17],[VIRTIO_NET_F_CTRL_VQ ],
    [18],[VIRTIO_NET_F_CTRL_RX ],
    [19],[VIRTIO_NET_F_CTRL_VLAN ],
    [21],[VIRTIO_NET_F_GUEST_ANNOUNCE],
    [22],[VIRTIO_NET_F_MQ],
    [23],[VIRTIO_NET_F_CTRL_MAC_ADDR],
    [41],[VIRTIO_NET_F_GUEST_RSC4 ],
    [42],[VIRTIO_NET_F_GUEST_RSC6 ],
    [61],[VIRTIO_NET_F_RSC_EXT],
    [62],[VIRTIO_NET_F_STANDBY],
  ),
  caption: [网卡设备特性位],
)

#empty_par

当数据包被复制到接收队列中的缓冲区后，最佳的处理方法是禁用接受队列发来的中断通知，并处理数据包，直到处理完所有的包为止，然后在重新启用中断。

数据包中的`num_buffers`字段表示该数据包分布在多少个描述符上（包括本描述符）：如果未启用`VIRTIO_NET_F_MRG_RXBUF`，则该值始终为 $1$。这样就可以接收大数据包，而无需分配大缓冲区：一个缓冲区放不下的数据包数据可以继续放置在下一个缓冲区中，以此类推。在这种情况下，虚拟队列中至少会有2个使用过的 `num_buffers` 缓冲区，设备会将它们串联起来形成一个数据包，其方式类似于将数据包存储在分布于多个描述符的单个缓冲区中。其他缓冲区不会以  `virtio_net_hdr` 结构开头。
如果 `num_buffers` 为 $1$，则整个数据包都放置在此缓冲区中，紧接在 `virtio_net_hdr` 结构之后。
如果启用了 `VIRTIO_NET_F_GUEST_CSUM` 特性，则可以设置标志中的 `VIRTIO_NET_HDR_F_DATA_VALID` 位：如果设置了该位，则表示设备已验证了数据包校验和。如果有多个封装协议，则已验证了一级校验和。

网卡与输入设备虽然都有与VirtIO操作通信模式相异的事件，但它们之间还有不同之处，这是因为输入设备需要接受的是可以直接进行逐字节拷贝（即实现了`Copy` `trait`）的基本类型数据，其大小极小（仅64位）使得拷贝过程不会影响性能。但是网卡所接受的内容是一整个数据包，其大小可能达到上千字节。如果逐字节拷贝这个数据，那么对性能的影响将会是不可接受的。因此可行的方案是直接保持数据在内存中的存放位置不懂，仅传递指针。在一些情况下，使用者可能想要自行决定网络收发的数据包需要放在什么地方（如Alien中数据包需要跨域进行传递，因此需要被放置在共享堆上）。另外的情况下使用者可能想要开箱即用而不关心数据包实际上存放在了哪里。因此向使用者提供了两种不同的驱动：`VirtIONet`和`VirtIONetRaw`。从名称上可以看出，后者允许使用者自行为数据包收发分配内存空间，并只需向驱动提供数据包的地址即可；前者则在基础驱动之上进行了更多的封装，提供了直接传入数据包进行发送，接受数据包的功能。当然这会带来一定的性能损失，对性能有追求的使用者应该使用基础的驱动。

== Uart16550驱动

这是一个物理存在的串口设备。与VirtIO系列的设备不同。因此它的驱动也和VirtIO设备的驱动分开成了两份代码。串口设备用于在多个设备间进行字节粒度的数据传输。它的通信模式也更加简单：往其某个寄存器中写入数据即是发送，而从某个寄存器中读取数据即是接受。

与VirtIO设备相同，对寄存器的操作也被归纳成了一个`trait`，提供按字节对一段内存进行读写的能力。该段内存被映射到设备寄存器上。

