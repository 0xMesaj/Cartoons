const { expect } = require('chai');
const { ethers } = require('hardhat');

const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

describe('Cartoons NFT Tests', () => {
    let leafNodes,merkleTree,cartoons,rootHash,leaf,hexProof;
    beforeEach(async () => {
        [whitelist1,whitelist2,whitelist3,whitelist4,whitelist5,whitelist6,hacker,unverifiedMinter] = await ethers.getSigners();
        cartoonsFactory = await ethers.getContractFactory('Cartoons');
        exploitFactory = await ethers.getContractFactory('ExploitSim');

        let whitelist = [
            whitelist1.address,
            whitelist2.address,
            whitelist3.address,
            whitelist4.address,
            whitelist5.address,
            whitelist6.address
        ]
        
        leafNodes = whitelist.map(item => keccak256(item))
        merkleTree = new MerkleTree(leafNodes, keccak256, {sortPairs: true});
        rootHash = merkleTree.getRoot();
        leaf = leafNodes[0]
        hexProof = merkleTree.getHexProof(leaf)
    
        cartoons = await cartoonsFactory.deploy(rootHash,2);
        // console.log("Root = " + rootHash.toString('hex'))
        // console.log("Proof = " + hexProof)
        // console.log("Whitelist Merkle Tree \n", merkleTree.toString());
        // console.log("Cartoons Deployed to: "+ cartoons.address)

    });


    it('Cartoons Test Whitelist and Public Mint:', async () => {
        ////////////////// TEST WHITELIST MINT //////////////////
        await expect(cartoons.connect(whitelist1).whitelistMint(hexProof,1,{value: ethers.utils.parseEther('0.07')})).to.be.revertedWith('Cartoons Whitelist Mint Not Active')
        await expect(cartoons.connect(hacker).setWhitelistMintActive(true)).to.be.revertedWith('Ownable: caller is not the owner')
        await cartoons.setWhitelistMintActive(true)

        // Whitelist mint from whitelist1 and verify contract is tracking count properly
        await cartoons.connect(whitelist1).whitelistMint(hexProof,1,{value: ethers.utils.parseEther('0.07')})
        expect(await cartoons.connect(whitelist1).getAllowedMintAmount(hexProof,whitelist1.address)).to.equal('1')
        await cartoons.connect(whitelist1).whitelistMint(hexProof,1,{value: ethers.utils.parseEther('0.07')})
        expect(await cartoons.connect(whitelist1).getAllowedMintAmount(hexProof,whitelist1.address)).to.equal('0')

        expect(await cartoons.connect(hacker).getAllowedMintAmount(hexProof,whitelist1.address)).to.equal('0')  // un-whitelisted address should have 0 allowed mints

        // Whitelist mint from whitelist2
        const hexProof2 = merkleTree.getHexProof(keccak256(whitelist2.address))
        await expect(cartoons.connect(whitelist2).whitelistMint(hexProof2,3,{value: ethers.utils.parseEther('0.21')})).to.be.revertedWith('Requested Claim Amount Invalid')  // Try to mint 3 when max should be 2
        await cartoons.connect(whitelist2).whitelistMint(hexProof2,2,{value: ethers.utils.parseEther('0.14')})
        expect(await cartoons.connect(whitelist2).getAllowedMintAmount(hexProof2,whitelist2.address)).to.equal('0')
        await expect(cartoons.connect(whitelist2).whitelistMint(hexProof2,1,{value: ethers.utils.parseEther('0.07')})).to.be.revertedWith('Requested Claim Amount Invalid')  // Try to mint 1 once 2 whitelist mints already used

        ////////////////// TEST PUBLIC MINT //////////////////
        await expect(cartoons.publicMint(1,{value: ethers.utils.parseEther('0.07')})).to.be.revertedWith('Cartoons Public Mint Not Active')
        await cartoons.setPublicMintActive(true)
        await expect(cartoons.publicMint(2,{value: ethers.utils.parseEther('0.14')})).to.be.revertedWith('Requested Mint Amount Exceeds Limit Per Tx')
        await expect(cartoons.publicMint(1,{value: ethers.utils.parseEther('0.069')})).to.be.revertedWith('Insufficient Payment')

        await cartoons.publicMint(1,{value: ethers.utils.parseEther('0.07')})

        // Test withdraw functionality
        var owner = await cartoons.owner()
        var prov = ethers.provider;
        var prebal = await prov.getBalance(owner)
        await cartoons.withdrawEth()
        var bal = await prov.getBalance(owner)
        await expect(parseInt(bal._hex)).to.be.greaterThan(parseInt(prebal._hex))
    });

    it('Cartoons Merkle Tree Exploit Sim:', async () => {
        await cartoons.setWhitelistMintActive(true)
        // Try various ways to exploit the merkle tree set up
        // Try to mint from whitelist2 address using whitelist1's proof
        await expect(cartoons.connect(whitelist2).whitelistMint(hexProof,2,{value: ethers.utils.parseEther('0.14')})).to.be.revertedWith('Invalid Proof')
        // Try to append ourselves as the hacker to the whitelist -> generate new merkle tree with us included and generate proof from it
        let hacker_whitelist = [
            whitelist1.address,
            whitelist2.address,
            whitelist3.address,
            whitelist4.address,
            whitelist5.address,
            whitelist6.address,
            hacker.address
        ]
        leafNodesHacker = hacker_whitelist.map(item => keccak256(item))
        merkleTreeHacker = new MerkleTree(leafNodesHacker, keccak256, {sortPairs: true});
        hexProofHacker = merkleTree.getHexProof(keccak256(hacker.address))
        await expect(cartoons.connect(hacker).whitelistMint(hexProofHacker,2,{value: ethers.utils.parseEther('0.14')})).to.be.revertedWith('Invalid Proof')
    })

    
    it('Cartoons Exploit Defense Sim:', async () => {
        const reentrancy = await exploitFactory.deploy(cartoons.address);

        // Try to Multicall and Reentrancy Exploit Ourselves
        await cartoons.setPublicMintActive(true)
        await expect(reentrancy.multicallExploit({value: ethers.utils.parseEther('0.14')})).to.be.revertedWith('Minting from Contract not Allowed') 
        await expect(reentrancy.reentrancyExploit({value: ethers.utils.parseEther('0.14')})).to.be.revertedWith('Minting from Contract not Allowed') 
    });
});