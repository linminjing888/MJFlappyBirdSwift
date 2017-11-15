//
//  GameScene.swift
//  MJFlappyBird
//
//  Created by YXCZ on 17/9/4.
//  Copyright © 2017年 JingJing_Lin. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit

/// 游戏状态
enum GameStatus {
    case idle /// 初始化
    case running /// 游戏运行中
    case over /// 游戏结束
}

class GameScene: SKScene,SKPhysicsContactDelegate {
    
    /// 背景色
    var skyColor:SKColor!
    /// 小鸟精灵
    var bird :SKSpriteNode!
    /// 竖直管缺口
    let verticalPipeGap = 150.0;
    /// 向上管纹理
    var pipeTextureUp:SKTexture!
    /// 向下管纹理
    var pipeTextureDown:SKTexture!
    /// 储存陆地、天空和管道
    var moving:SKNode!
    /// 储存所有上下管道
    var pipes:SKNode!
    /// 游戏状态为初始状态
    var gameStatus:GameStatus = .idle
    /// 懒加载 只有在gameOverLabel第一次被调用的时候才会创建
    lazy var gameOverLabel:SKLabelNode = {
        let label = SKLabelNode(fontNamed: "Chalkduster")
        label.text = "Game Over"
        return label
    }()
    /// 分数
    var score: NSInteger = 0
    ///分数Label
    lazy var scoreLabelNode:SKLabelNode = {
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.zPosition = 100
        label.text = "0"
        return label
    }()
    
    /// 设置物理体的标示符  <<左移运算符  左移一位，相当于扩大2倍
    let birdCategory: UInt32 = 1 << 0  //1
    let worldCategory: UInt32 = 1 << 1  //2
    let pipeCategory: UInt32 = 1 << 2  //4
    let scoreCategory: UInt32 = 1 << 3  //8
    
    override func didMove(to view: SKView) {
        
        skyColor = SKColor(red: 81.0/255.0, green: 192.0/255.0, blue: 201.0/255.0, alpha: 1.0)
        self.backgroundColor = skyColor
        //给场景添加一个物理体，限制了游戏范围
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        //物理世界的碰撞检测代理为场景自己
        self.physicsWorld.contactDelegate = self;
        //设置重力
        self.physicsWorld.gravity = CGVector(dx: 0.0, dy: -3.0)
        
        moving = SKNode()
        self.addChild(moving)
        pipes = SKNode()
        moving.addChild(pipes)
        
        // 地面
        let groundTexture = SKTexture(imageNamed: "land")
        groundTexture.filteringMode = .nearest
        for i in 0..<2 + Int(self.frame.size.width / (groundTexture.size().width * 2)) {
            let i = CGFloat(i)
            let sprite = SKSpriteNode(texture: groundTexture)
            sprite.setScale(2.0)
            // SKSpriteNode的默认锚点为(0.5,0.5)即它的中心点。
            sprite.anchorPoint = CGPoint(x: 0, y: 0)
            sprite.position = CGPoint(x: i * sprite.size.width, y: 0)
            self.moveGround(sprite: sprite, timer: 0.02)
            moving.addChild(sprite)
        }
        
        // 配置陆地物理体
        let ground = SKNode()
        ground.position = CGPoint(x: 0, y: groundTexture.size().height)
        ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: self.frame.size.width, height: groundTexture.size().height * 2.0))
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = worldCategory
        self.addChild(ground)
        
        // 天空
        let skyTexture = SKTexture(imageNamed: "sky")
        skyTexture.filteringMode = .nearest
        for i in 0..<2 + Int(self.frame.size.width / (skyTexture.size().width * 2)) {
            let i = CGFloat(i)
            let sprite = SKSpriteNode(texture: skyTexture)
            sprite.setScale(2.0)
            sprite.zPosition = -20
            sprite.anchorPoint = CGPoint(x: 0, y:0)
            sprite.position = CGPoint(x: i * sprite.size.width, y:groundTexture.size().height * 2.0)
            self.moveGround(sprite: sprite, timer: 0.1)
            moving.addChild(sprite)
        }
        
        // 小鸟
        bird = SKSpriteNode(imageNamed: "bird-01")
        bird.setScale(1.5)
        addChild(bird)
        
        // 配置小鸟物理体
        bird.physicsBody = SKPhysicsBody(circleOfRadius: bird.size.height / 2.0)
        //        bird.physicsBody = SKPhysicsBody(texture: bird.texture!, size: bird.size)
        bird.physicsBody?.allowsRotation = false
        bird.physicsBody?.categoryBitMask = birdCategory
        bird.physicsBody?.contactTestBitMask = worldCategory | pipeCategory
        
        self.idleStatus()
        
    }
    func idleStatus() {
        gameStatus = .idle
        
        removeAllPipesNode()
        
        // 移除 游戏结束提示
        gameOverLabel.removeFromParent()
        // 移除分数提示
        scoreLabelNode.removeFromParent()
        
        bird.position = CGPoint(x: self.frame.size.width * 0.35, y: self.frame.size.height * 0.6)
        // isDynamic的作用是设置这个物理体当前是否会受到物理环境的影响，默认是true
        bird.physicsBody?.isDynamic = false
        
        self.birdStartFly()
//        // 重新开始动画
        moving.speed = 1
    }
    func runningStatus() {
        gameStatus = .running
        
        // 重设分数
        score = 0
        scoreLabelNode.text = String(score)
        self.addChild(scoreLabelNode)
        scoreLabelNode.position = CGPoint(x: self.frame.midX, y: 3 * self.frame.size.height / 4)
        
        bird.physicsBody?.isDynamic = true
        bird.physicsBody?.collisionBitMask = worldCategory | pipeCategory
        
        startCreateRandomPipes()
    }
    func overStatus() {
        gameStatus = .over
        
        birdStopFly()
        
        stopCreateRandomPipes()
        
        
        addChild(gameOverLabel)
        gameOverLabel.position = CGPoint(x: self.size.width * 0.5, y: self.size.height)
        isUserInteractionEnabled = false;
        //让gameOverLabel通过一个动画action移动到屏幕中间
        let delay = SKAction.wait(forDuration: TimeInterval(1))
        let move = SKAction.move(by: CGVector(dx: 0, dy: -self.size.height * 0.5), duration: 1)
        gameOverLabel.run(SKAction.sequence([delay,move]), completion:{
            //动画结束 允许用户点击屏幕
            self.isUserInteractionEnabled = true
        })
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch gameStatus {
        case .idle:
            runningStatus()
            
            break
        case .running:
            for _ in touches {
                
                bird.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
                // 施加一个均匀作用于物理体的推力
                bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 10))
            }
            break
            
        case .over:
            idleStatus()
            break
        }
    }
  
    /// SKPhysicsContact对象是包含着碰撞的两个物理体的,分别是bodyA和bodyB
    ///
    /// - Parameter contact: SKPhysicsContact
    func didBegin(_ contact: SKPhysicsContact) {
        
        if gameStatus != .running {
            return
        }
        // 如果通过分数区域 按位与运算 4&5的值为4。这里4的二进制是“100”，5的二进制是“101” 按位与就是100&101=100（即十进制为4）
        if (contact.bodyA.categoryBitMask & scoreCategory) == scoreCategory || (contact.bodyB.categoryBitMask & scoreCategory) == scoreCategory {

            score += 1
            print(score)
            scoreLabelNode.text = String(score)

            scoreLabelNode.run(SKAction.sequence([SKAction.scale(to: 1.5, duration: TimeInterval(0.1)),SKAction.scale(to: 1.0, duration: TimeInterval(0.1))]))
        }else{
        
            moving.speed = 0
            bird.physicsBody?.collisionBitMask = worldCategory
            //碰撞翻转
            //            bird.run(SKAction.rotate(byAngle: .pi * CGFloat(bird.position.y) * 0.01, duration: 1))
            
    //            bgFlash()
        
            overStatus()
        }
    }
    /// 背景闪光
    func bgFlash() {
        let bgFlash = SKAction.run({
            self.backgroundColor = SKColor(red: 1, green: 0, blue: 0, alpha: 1.0)}
        )
        let bgNormal = SKAction.run({
            self.backgroundColor = self.skyColor;
        })
        let bgFlashAndNormal = SKAction.sequence([bgFlash,SKAction.wait(forDuration: (0.05)),bgNormal,SKAction.wait(forDuration: (0.05))])
        self.run(SKAction.sequence([SKAction.repeat(bgFlashAndNormal, count: 4)]), withKey: "falsh")
        self.removeAction(forKey: "flash")
    }
    //陆地移动动画
    func moveGround(sprite:SKSpriteNode,timer:CGFloat) {
        let moveGroupSprite = SKAction.moveBy(x: -sprite.size.width, y: 0, duration: TimeInterval(timer * sprite.size.width))
        let resetGroupSprite = SKAction.moveBy(x: sprite.size.width, y: 0, duration: 0.0)
        //永远移动 组动作
        let moveGroundSpritesForever = SKAction.repeatForever(SKAction.sequence([moveGroupSprite,resetGroupSprite]))
        sprite.run(moveGroundSpritesForever)
    }
    
    ///  小鸟飞的动画
    func birdStartFly()  {
        let birdTexture1 = SKTexture(imageNamed: "bird-01")
        birdTexture1.filteringMode = .nearest
        let birdTexture2 = SKTexture(imageNamed: "bird-02")
        birdTexture2.filteringMode = .nearest
        let birdTexture3 = SKTexture(imageNamed: "bird-03")
        birdTexture3.filteringMode = .nearest
        let anim = SKAction.animate(with: [birdTexture1,birdTexture2,birdTexture3], timePerFrame: 0.2)
        bird.run(SKAction.repeatForever(anim), withKey: "fly")
    }
    ///  小鸟停止飞动画
    func birdStopFly()  {
        bird.removeAction(forKey: "fly")
    }
    
    /// 随机 创建
    func startCreateRandomPipes() {
        let spawn = SKAction.run {
            self.creatSpawnPipes()
        }
        let delay = SKAction.wait(forDuration: TimeInterval(2.0))
        let spawnThenDelay = SKAction.sequence([spawn,delay])
        let spawnThenDelayForever = SKAction.repeatForever(spawnThenDelay)
        self.run(spawnThenDelayForever, withKey: "createPipe")
    }
    ///停止创建管道
    func stopCreateRandomPipes() {
        self.removeAction(forKey: "createPipe")
    }
    /// 移除所有已经存在的上下管
    func removeAllPipesNode() {
        pipes.removeAllChildren()
    }
    ///创建一对水管
    func creatSpawnPipes() {
        // 管道纹理
        pipeTextureUp = SKTexture(imageNamed: "PipeUp")
        pipeTextureUp.filteringMode = .nearest
        pipeTextureDown = SKTexture(imageNamed: "PipeDown")
        pipeTextureDown.filteringMode = .nearest
        
        let pipePair = SKNode()
        pipePair.position = CGPoint(x: self.frame.size.width + pipeTextureUp.size().width * 2, y: 0)
        // z值的节点(用于排序)。负z是”进入“屏幕,正面z是“出去”屏幕。
        pipePair.zPosition = -10;
        
        // 随机的Y值
        let height = UInt32(self.frame.size.height / 5)
        let y = Double(arc4random_uniform(height) + height)
        
        let pipeDown = SKSpriteNode(texture: pipeTextureDown)
        pipeDown.setScale(2.0)
        pipeDown.position = CGPoint(x: 0.0, y: y + Double(pipeDown.size.height)+verticalPipeGap)
        
        pipeDown.physicsBody = SKPhysicsBody(rectangleOf: pipeDown.size)
        pipeDown.physicsBody?.isDynamic = false
        pipeDown.physicsBody?.categoryBitMask = pipeCategory
        pipeDown.physicsBody?.contactTestBitMask = birdCategory
        pipePair.addChild(pipeDown)
        
        let pipeUp = SKSpriteNode(texture: pipeTextureUp)
        pipeUp.setScale(2.0)
        pipeUp.position = CGPoint(x: 0.0, y: y)
        pipeUp.physicsBody = SKPhysicsBody(rectangleOf: pipeUp.size)
        pipeUp.physicsBody?.isDynamic = false
        pipeUp.physicsBody?.categoryBitMask = pipeCategory
        pipeUp.physicsBody?.contactTestBitMask = birdCategory
        pipePair.addChild(pipeUp)
        
        let contactNode = SKNode()
        contactNode.position = CGPoint(x: pipeDown.size.width, y: self.frame.midY)
        contactNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: pipeUp.size.width, height: self.frame.size.height))
        contactNode.physicsBody?.isDynamic = false
        contactNode.physicsBody?.categoryBitMask = scoreCategory
        contactNode.physicsBody?.contactTestBitMask = birdCategory
        pipePair.addChild(contactNode)
        
        // 管道移动动作
        let distanceToMove = CGFloat(self.frame.size.width + 2.0*pipeTextureUp.size().width)
        let movePipes = SKAction.moveBy(x: -distanceToMove, y: 0.0, duration: TimeInterval(0.01 * distanceToMove))
        let removePipes = SKAction.removeFromParent()
        let movePipesAndRemove = SKAction.sequence([movePipes,removePipes])
        pipePair.run(movePipesAndRemove)
        
        pipes.addChild(pipePair)
    }
    
    // update()方法为SKScene自带的系统方法，在画面每一帧刷新的时候就会调用一次
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        //调整头先着地
        let value = bird.physicsBody!.velocity.dy * (bird.physicsBody!.velocity.dy < 0 ? 0.003 : 0.001)
        bird.zRotation = min(max(-1, value),0.5)

    }
}
