= 总结

本文详细讲述了如何完全使用安全的Rust语言开发一个设备驱动，提供了可直接使用的Rust包，并将其作为一个隔离域加入到Alien中，且对这种方法实现的驱动进行了性能测试，展示其取代现有不安全驱动的可能性。此工作既是对于Alien系统组成部分的开发，也是使用语言机制强化系统安全的又一个实践尝试，相信这会使基于语言机制的操作系统安全领域的研究走得更远，为其他的研究者和开发者起到参考作用。