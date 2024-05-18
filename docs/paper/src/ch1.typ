= 引入

操作系统的最初目的是调度硬件资源和促进计算机上多项任务的执行，而现在已经有了长足的发展。随着计算机硬件和软件的不断进步，出现了 Windows 和 Linux 等主流操作系统，其特点是包含了操作系统所需的大部分基本功能。然而，这种功能集成带来了潜在的安全漏洞，因为操作系统中的任何错误都可能导致整个系统崩溃。操作系统中错误的来源多样，可能由于用户的误操作带来负面影响，也可能有恶意攻击者对操作系统或其中的某些部分进行攻击。@y1

多用户操作系统的出现要求了操作系统对于用户进行的权限管理和隔离，以避免不同用户之间的相互影响。而多核处理器的出现与多线程操作系统又带来了新的攻击方式、新的安全问题和挑战。操作系统开发人员需要为系统设计管理和访问的权限，如强制访问控制（mandatory access control），并对其进行验证以确保其安全方案是正确的（如使用形式化验证[]），能够满足安全性需求。MAC架构可以对所有的下属对象（如用户和进程、内存、文件、设备、端口等）。现代处理器使用多特权级管理，把系统分为内核态（ring 0）和用户态（ring 3）。这一方案精细化了隔离的粒度大小，提供了硬件层面的保护机制，在不同特权级的切换之间需要进行权限验证，以此保护在复杂的计算机系统中保护内核和用户应用的正常运行。通常，一个进程无法修改属于更高权限的资源文件。ring0特权级中的代码将会被视为可信任的。https://www.giac.org/paper/gsec/2776/operating-system-security-secure-operating-systems/104723

开发安全内核的基本原则是使用经过形式化定义的安全模型，满足完全、强制化、安全需求被检验满足等条件。之后，该模型需要被正确的使用编程语言实现出来。操作系统在任何计算机系统中都扮演着重要地位，因此任何在其中出现的问题都将会威胁到整个计算机系统和其上运行的所有软件。一个被入侵的应用可能导致另一个设备也被入侵。

在现代操作系统开发中，安全性的重要性日益突出。这促使开发人员寻求能最大限度减少操作系统出错的解决方案。在这种情况下，微内核的概念应运而生。微内核方法旨在通过将必要的功能（如文件系统和硬件驱动程序）委托给用户空间程序来简化操作系统本身的复杂性。微内核的主要优势在于该架构可以提供更安全和稳定的操作系统。这种降低复杂性和分离功能的做法降低了开发和维护的难度，同时也减少了出现漏洞的可能性。此外，在用户空间运行操作系统模块可降低其权限，从而减轻某些类型的攻击。因为只有必要的服务在内核空间中运行，微内核操作系统拥有更小的攻击面，让攻击者更难找到其中的漏洞。并且，一个用户级的进程的崩溃不会影响到整个操作系统，因为微内核只负责管理进程和内存。微内核架构的另一个优势是它使得操作系统更加灵活和模块化。在用户态运行的服务可以更容易的被替换、移除或者重置而不影响系统的其他部分。这令操作系统可定制化，可满足特定需要。微内核的缺点则在于内核态和用户态的分离带来了大量的特权级切换，这使得微内核系统比宏内核更慢，尤其是在对系统调用性能要求高的应用场景当中。https://www.geeksforgeeks.org/microkernel-in-operating-systems/

现有的操作系统安全解决方案主要依赖于基于硬件的隔离，如 ARM TrustZone。这种方法定义了一个可信区，只有安全性要求高的程序才能在此执行，确保与普通区完全隔离。TrustZone最初在ARMv7发布时提出，并逐渐被加入到芯片中。该处可信区只能被可信的系统和软件读取，其他任何调试方法和硬件访问都会被阻止。对其的访问需要通过密钥验证，密钥被写入芯片中，使得后期的攻击无法成立。用VMFUNC切换页表、内存保护密钥、内存标签扩展等硬件隔离技术提供了一些低负载的硬件隔离机制，其负载量与函数调用时的开销相接近。

然而，目前的硬件隔离机制存在一定的局限性。首先，它们需要特定的硬件支持，因此成本较高，而且缺乏通用性。其次，基于硬件方法的实施缺陷可能会带来不易修改的漏洞。并且由于需要其保存通用与扩展寄存器，还要切换栈空间，就算在理想的地址空间切换不耗时时，其与基于Rust语言的隔离相比开销仍较大。Rust语言在实现隔离的同时避免了这两个开销，它的开销与函数调用相同。在实际的应用场景下，Rust只比C++实现慢4~8%。[Understanding the Overheads of Hardware and Language-Based IPC Mechanisms]

为了解决这些不足，人们正在考虑基于软件的安全隔离解决方案。基于软件的安全隔离解决方案有望提供更大的灵活性和适应性，而且可以在各种硬件平台上实施。这些技术的开发有望提高操作系统的安全性，降低与系统崩溃和漏洞相关的风险。Nooks提出了隔离域的思想，并给出了一些安全约束，如故障隔离的思想。奇点操作系统开创性地使用一种新的安全语言来开发操作系统内核，带来了编译器保证的系统安全研究方向。目前已有多个项目在开展操作系统层面提高系统隔离性和安全性的尝试，包括 J-Kernel、KaffeOS、红叶操作系统、Theseus OS 和 Asterinas 等。它们旨在通过软件层面的设计和实施、安全编程语言的使用来提高安全性。

J-Kernel 认为仅靠语言安全不足以保证故障隔离和子系统更换，因此它基于Java语言实现了数据传输的接口和代理。其中的每个对象在传递时都会经由一层代理进行包装，并传递一个特殊的引用对象。该引用对象可以调用方法，该系统可以把各个隔离对象进行分割，但是这个过程中需要对非引用而是直接传输的参数进行深拷贝。由于内核的工作常见大量数据的处理传递，这种函数调用时增加的巨大开销是很难接受的。此外，由于其传递的引用没有做可用性检查，因此它的故障隔离是单向的：J-Kernel可以阻止调用者的崩溃影响到引用对象的创建者，但是当引用对象创建者本身崩溃时，其调用者之后的使用将也会崩溃，并未完全做到故障隔离。

KaffeOS没有使用代理，而是使用了写屏障技术。在KaffeOS中存在两种堆对象，分别是私有堆和跨域共享堆。它对于共享堆上的对象设置了称为写屏障的约束，该约束管理所有隔离部分对其的引用与垃圾回收。然而，这个模型的缺陷在于当一个隔离部分在对共享堆上的数据修改到一半却崩溃了时，共享堆上的数据将可能保留在不合法的状态并就这样被其他的隔离部分所读取，此时故障将传递给这个正在执行读取操作的部分。此外，隔离对象也需要在跨域调用的时候进行深拷贝，并且动态检查指针和垃圾回收带来的开销也无法忽视。

奇点操作系统使用了全新的模式来进行故障隔离。它重点使用了编译期即可确定的静态所有权来完成这一目标。类似KaffeOS，奇点也使用了交换堆和私有堆。它创新地为交换堆用于在各个隔离部分之间传递数据而无需深拷贝。这些约束实现的保证都在于其开发者发明的Sing\#语言：这种专门为安全隔离OS设计的语言使用了多种新颖的静态分析和验证技术，能够满足所有权约束系统。奇点规定了每个交换堆上分配的对象只能拥有单一所有权，没有所有权的域不能对其进行访问。在跨域调用的时候，交换堆上的对象的所有权会被转移到被调用者所在的域。因此，崩溃的域无法影响到其他的部分，它不会让已经存在的引用消失（因为这样的引用根本就不允许被创建），也无法让正在被引用的交换堆对象处在不合法的状态中。此外，所有权的转移实现了零复制拷贝，减少了函数调用时数据传递所带来的开销。移动语义保证了该对象是当前域专有的，因此接受者可以随意对其进行修改。奇点的系统设计严重依赖于其开发的Sing\#语言，因此难以被广泛使用，但是其思想非常值得参考。

红叶操作系统受到了J-Kernel、KaffeOS、奇点的启发，使用Rust语言原生的所有权系统和内存安全性来执行故障隔离。在数据保存和移动时，使用了KaffeOS和奇点的共享堆于私有堆，并且强制规定共享堆上的数据不能拥有可变引用，因此支持奇点的零拷贝通信。使用了J-Kernel的代理技术来规范跨域的函数调用，使用IDL来为各个隔离域设计接口。红叶的故障隔离规范并不依赖于Rust，而是被其独立出来，抽象为隔离规范的集合。在红叶中，跨域执行的函数调用无需进行线程的切换，而是直接把线程移动到了另一个域中。此方法可以减少系统中的线程上下文切换，同时提高了代码的自然性。

Theseus OS 是对操作系统模块化和动态更新进行尝试的一个操作系统。它致力于减少各个组件进行交互时所需的状态，对其进行了最小的、明确的定义，并构筑边界使得这些状态不会在运行时被其他组件进行修改。此外，它也使用了Rust语言，借助其强大的编译器与机制来确保一些操作系统中的概念正确实现。

Asterinas 是一个用Rust编写的支持Linux适配的操作系统内核，这意味着它可以用于取代Linux，并伴随着内存安全语言带来的一系列好处。它限制了内核中不安全代码的使用，定义了一个最小的可信代码块（TCB）用于放置必须的不安全代码。该内核的framekernel架构将内核划分为TCB和剩余部分。其中TCB会包装内部的低级代码并对系统其余部分提供高级的交互编程接口，而其余部分则必须完全用安全代码写就，以阻止对内存的不安全操作，减少风险。TCB和其余部分运行在同一地址空间中，通过函数调用进行交互，因此其效率能做到与宏内核相近。微内核所提供的安全性保证则交由Rust编译器在编译期间完成检查。同时Asterinas提供了对开发者友好的工具OSDK，用于把其各个模块的开发过程规范化，提高效率。

受到红叶、Asterinas等系统的启发，Alien 操作系统的isolation版本（以下简称Alien）尝试实现一个基于Rust的安全性开发，在内核中使用多个隔离域封装内核各部分功能以实现故障隔离，使用TCB并限制不安全代码的使用以加强内存安全性，支持对各域进行任何时候的动态加载的操作系统。通过探索基于软件的安全隔离方法，本项目旨在为操作系统中的安全设备驱动程序领域做出贡献，并深入探讨与此类解决方案相关的潜在优势和挑战。
