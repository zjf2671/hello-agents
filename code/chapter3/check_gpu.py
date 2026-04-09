import torch

print("PyTorch 版本:", torch.__version__)
print("CUDA 是否可用:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("CUDA 版本:", torch.version.cuda)
    print("GPU 数量:", torch.cuda.device_count())
    print("当前 GPU:", torch.cuda.current_device())
    print("GPU 名称:", torch.cuda.get_device_name(0))
else:
    print("CUDA 不可用，使用 CPU")

# 测试你的原始代码
device = "cuda" if torch.cuda.is_available() else "cpu"
print("\n你的代码输出:", device)