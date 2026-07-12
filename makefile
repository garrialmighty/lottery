-include .env

build:; forge build

install:; forge install cyfrin/foundry-devops@0.4.0 && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std && forge install transmissions11/solmate

deploy-anvil:
	 forge script --rpc-url $(ANVIL_URL) ./script/Lottery.s.sol --broadcast --private-key $(ANVIL_PRIVATE_KEY) -vvvv

deploy-sepolia:
	@forge script script/Lottery.s.sol --rpc-url $(SEPOLIA_RPC_URL) --account deployer --broadcast --verify -vvvv