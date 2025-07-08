package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"strings"
	"time"
)

// 实践 POW， 编写程序（编程语言不限）用自己的昵称 + nonce，不断修改nonce 进行 sha256 Hash 运算：
// 直到满足 4 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。
// 再次运算直到满足 5 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。

func findHashWithZeros(targetZeros int, nickname string) string {
	var nonce int64 = 0
	target := strings.Repeat("0", targetZeros)
	startTime := time.Now()

	fmt.Printf("开始寻找 %d 个 0 开头的哈希值...\n", targetZeros)
	var data string
	var hashStr string
	for {
		// 拼接字符串：nonce + nickname
		data = fmt.Sprintf("%d%s", nonce, nickname)

		// 计算SHA256哈希
		hash := sha256.Sum256([]byte(data))
		hashStr = fmt.Sprintf("%x", hash)

		if strings.HasPrefix(hashStr, target) {
			elapsed := time.Since(startTime)

			fmt.Printf("\n=== 找到 %d 个 0 开头的哈希值 ===\n", targetZeros)
			fmt.Printf("花费时间: %v\n", elapsed)
			fmt.Printf("Hash 内容: %s\n", data)
			fmt.Printf("Hash 值: %s\n", hashStr)
			fmt.Printf("尝试次数: %d\n", nonce+1)
			fmt.Println("================================\n")
			break
		}

		nonce++

		// 每10000次尝试输出一次进度
		if nonce%10000 == 0 {
			fmt.Printf("已尝试 %d 次...\n", nonce)
		}
	}
	return data
}

// 实践非对称加密 RSA（编程语言不限）：
// 先生成一个公私钥对

func GenRsaKey(bits int) (privateKey, publicKey string) {
	priKey, err2 := rsa.GenerateKey(rand.Reader, bits)
	if err2 != nil {
		panic(err2)
	}

	derStream := x509.MarshalPKCS1PrivateKey(priKey)
	block := &pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: derStream,
	}
	prvKey := pem.EncodeToMemory(block)
	puKey := &priKey.PublicKey
	derPkix, err := x509.MarshalPKIXPublicKey(puKey)
	if err != nil {
		panic(err)
	}
	block = &pem.Block{
		Type:  "PUBLIC KEY",
		Bytes: derPkix,
	}
	pubKey := pem.EncodeToMemory(block)

	privateKey = string(prvKey)
	publicKey = string(pubKey)
	return privateKey, publicKey
}

func main() {
	nickname := "zwg"

	// 寻找4个0开头的哈希值
	data := findHashWithZeros(4, nickname)

	// 寻找5个0开头的哈希值
	findHashWithZeros(5, nickname)

	// 用私钥对符合 POW 4 个 0 开头的哈希值的 "昵称 + nonce" 进行私钥签名
	// 用公钥验证

	privateKey, publicKey := GenRsaKey(2048)
	fmt.Println("生成的私钥:")
	fmt.Println(privateKey)
	fmt.Println("生成的公钥:")
	fmt.Println(publicKey)

	// 私钥签名
	block, _ := pem.Decode([]byte(privateKey))
	priKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		fmt.Printf("解析私钥失败: %v\n", err)
		return
	}
	hash := sha256.Sum256([]byte(data))
	signature, err := rsa.SignPKCS1v15(rand.Reader, priKey, crypto.SHA256, hash[:])
	if err != nil {
		fmt.Printf("签名失败: %v\n", err)
		return
	}

	fmt.Printf("\n=== RSA 签名验证 ===\n")
	fmt.Printf("原始数据: %s\n", data)
	fmt.Printf("数据哈希: %x\n", hash)
	fmt.Printf("签名完成，签名长度: %d 字节\n", len(signature))

	// 公钥验证
	pubBlock, _ := pem.Decode([]byte(publicKey))
	pubKeyInterface, err := x509.ParsePKIXPublicKey(pubBlock.Bytes)
	if err != nil {
		fmt.Printf("解析公钥失败: %v\n", err)
		return
	}

	rsaPublicKey, ok := pubKeyInterface.(*rsa.PublicKey)
	if !ok {
		fmt.Println("公钥类型转换失败")
		return
	}

	// 验证签名
	err = rsa.VerifyPKCS1v15(rsaPublicKey, crypto.SHA256, hash[:], signature)
	if err != nil {
		fmt.Printf("签名验证失败: %v\n", err)
	} else {
		fmt.Println("✅ 签名验证成功!")
	}
	fmt.Println("========================")
}
