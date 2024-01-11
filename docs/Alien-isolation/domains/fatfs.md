这是一个域，为内核提供操作fat文件系统的功能。

## 外界接口

需要用到：

```rust
/// domain-tools/interface
/// 开发中
/// 代表文件系统的trait。本域需要实现一个有`Fs` trait的结构体，内核通过Fs提供的函数来与本域交互。
pub trait Fs: Send + Sync + Basic {
	/// ls 命令？
	fn ls(&self, path: RRef<[u8; 512]>) -> RpcResult<RRef<[u8;512]>>;
}

/// domain-tools/interface
/// 开发中 | [查看其文档]()
/// 代表块设备的trait，内核其他部分都通过这个trait和块设备进行交互。
/// 文件系统的操作需要对块设备进行读写，故需要传入一个有`BlkDevice` trait的对象。
pub trait BlkDevice: Send + Sync + Basic {
	fn read(&mut self, block: u32, data: RRef<[u8; 512]>) -> RpcResult<RRef<[u8; 512]>>;
    fn write(&mut self, block: u32, data: &RRef<[u8; 512]>) -> RpcResult<usize>;
    fn get_capacity(&self) -> RpcResult<u64>;
    fn flush(&self) -> RpcResult<()>;
}

/// domain-tools/rref
/// domain-tools/libsyscall
```

向外提供：

```rust
/// 域入口，传入本域使用的块设备，返回指向自己的智能指针。
pub fn main(Box<dyn BlkDevice>) -> Box<dyn Fs>;
```

## 内部实现

##### FatFsDomain

作为返回对象，定义一个 `FatFsDomain` 结构体：

```rust
pub struct FatFsDomain {
    root: Arc<dyn VfsDentry>,
}
```

其中储存一个代表根目录的自动引用计数指针。
我们使用了`os-module/rvfs`提供的`fat-vfs`和`vfscore` crate，它们是独立的os子模块，提供了vfs的实现。

为其实现必须的trait `Fs`：

###### ls

```rust
	fn ls(&self, path: RRef<[u8; 512]>) -> RpcResult<RRef<[u8;512]>> {
		unimplemented!()
	}
```
暂未实现

##### main

看看`main()`的实现：
```rust
pub fn main(blk_device: Box<dyn BlkDevice>) -> Box<dyn Fs> {
	// 先创建出一个Fat文件系统，它需要一个 FatFsProvider 参数
    let fatfs = Arc::new(FatFs::<_, Mutex<()>>::new(ProviderImpl));
    // 把这个文件系统挂在根目录 "/" 上。获得一个指向 "/" 的目录项。
    let root = fatfs
        .clone() // 首先克隆此文件系统（是为了同时挂载多个fatfs吗，感觉此代码中不需要）
        .mount(0, "/", Some(Arc::new(FakeInode::new(blk_device))), &[])
        .unwrap(); // 挂载。需要传入一个 VfsInode 结构，代表整个块设备。
    println!("****Files In Root****");
    // 测试一下输出文件目录树。这需要传入一个有 Write trait的结构
    vfscore::path::print_fs_tree(&mut FakeOut, root.clone(), "".to_string(), true).unwrap(); 
    println!("List all file passed");
    Box::new(FatFsDomain::new(root)) // 把root装入FatFsDomain并返回
}
```

看出我们需要一些结构体来实现 FatFsProvider，Write，VfsInode（它又需要VfsFile）

`Write` 比较简单，直接调用libsyscall，让内核把目标字符串输出到终端。
```rust
struct FakeOut;
impl Write for FakeOut {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        libsyscall::write_console(s);
        Ok(())
    }
}
```

`FatFsProvider` 不知道是干什么的，需要一个 `current_time` 函数。目前的代码中直接返回了一个全0的时间。
```rust
#[derive(Clone)]
struct ProviderImpl;
impl FatFsProvider for ProviderImpl {
    fn current_time(&self) -> VfsTimeSpec {
        VfsTimeSpec::new(0, 0)
    }
}
```
##### FakeInode

定义了一个 FakeInode 结构体表示 Inode，存放文件的索引信息。
实现 `VfsInode` trait，它有很多的函数需要实现，不过现在的原型系统中，我们只对必要的函数简单的返回最高权限、全0的状态等。类型返回块设备。

`VfsInode` 又需要我们实现 `VfsFile` trait，我们现在实现了读、写、刷新。
> 疑问：Inode应该不仅限于指向整个块设备吧？现在的这个FakeInode只能向块设备中指定偏移的地方写入和读取。不太了解现在使用的vfs+fatfs模块需要我们额外做什么工作，需要讲解或者花时间阅读代码。
###### read_at

```rust
/// 从块设备中 offset 处读取数据到 buf 中，返回成功读取的字节数
fn read_at(&self, offset: u64, buf: &mut [u8]) -> VfsResult<usize> {
	let read_len = buf.len();
	let mut device = self.device.lock();
	let mut tmp_buf = RRef::new([0u8; 512]); // 块设备和文件系统在不同的域里，因此需要RRef类型（此数组定长，使用栈空间如何？）

	let mut read_offset = offset;
	let mut count = 0;

	// 块设备提供以512字节为单位的整块操作，需要分多次读入
	// 12 512
	while count < read_len {
		let block = read_offset / 512;
		let offset = read_offset % 512;
		let read_len = core::cmp::min(512 - offset as usize, read_len - count);
		tmp_buf = device.read(block as u32, tmp_buf).unwrap();
		buf[count..count + read_len]
			.copy_from_slice(&tmp_buf[offset as usize..offset as usize + read_len]);
		count += read_len;
		read_offset += read_len as u64;
	}
	Ok(count)
}
```

###### write_at

```rust
/// 把 buf 中的数据写入块设备偏移 offset 处。返回成功写入的字节数。
fn write_at(&self, offset: u64, buf: &[u8]) -> VfsResult<usize> {
	let write_len = buf.len();
	let mut device = self.device.lock();
	let mut tmp_buf = RRef::new([0u8; 512]);

	let mut write_offset = offset;
	let mut count = 0;

	// 12 512
	while count < write_len {
		let block = write_offset / 512;
		let offset = write_offset % 512;
		// 写入不是从块头开始时，为防止整块写入覆盖掉原有数据，先把原有数据进行读入
		// 疑问：结尾块时如果写入的数据不满一块，原有的最后不满的数据不会也被覆盖吗？
		// 是因为原型系统有限的操作确保那些地方都无意义吗？
		if offset != 0 { 
			tmp_buf = device.read(block as u32, tmp_buf).unwrap();
		}
		let write_len = core::cmp::min(512 - offset as usize, write_len - count);
		tmp_buf[offset as usize..offset as usize + write_len]
			.copy_from_slice(&buf[count..count + write_len]);
		device.write(block as u32, &tmp_buf).unwrap();
		count += write_len;
		write_offset += write_len as u64;
	}
	Ok(count)
}
```

###### flush

```rust
/// 直接调用块设备的刷新函数
fn flush(&self) -> VfsResult<()> {
	self.device.lock().flush().unwrap();
	Ok(())
}
```
