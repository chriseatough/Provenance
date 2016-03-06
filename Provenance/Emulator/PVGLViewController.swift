//
//  PVGLViewController.swift
//  Provenance
//
//  Created by Christopher Eatough on 19/02/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import GLKit
import QuartzCore

class PVGLViewController : GLKViewController {
    let glContext: EAGLContext
    let effect: GLKBaseEffect
    let emulatorCore: PVEmulatorCore
    
    var vertices = [GLKVector3]()
    var textureCoordinates = [GLKVector2]()
    var triangleVertices = [GLKVector3]()
    var triangleTexCoords = [GLKVector2]()
    var texture: GLuint = 0
    
    init(emulatorCore: PVEmulatorCore) {
        self.emulatorCore = emulatorCore
        self.glContext = EAGLContext(API: .OpenGLES2)
        self.effect = GLKBaseEffect()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        glDeleteTextures(GLsizei(1), &texture)
    }
    
    class func initWithEmulatorCore(emulatorCore: PVEmulatorCore) -> PVGLViewController {
        return PVGLViewController(emulatorCore: emulatorCore)
    }
    
    override func viewDidLoad() {
        self.preferredFramesPerSecond = 60
        EAGLContext.setCurrentContext(glContext)
        
        let view = self.view as! GLKView
        view.context = self.glContext
        
        setupTexture()
        
        super.viewDidLoad()
    }
    
    override func viewWillLayoutSubviews() {
        defer {
            print("viewWillLayoutSubviews")
            super.viewWillLayoutSubviews()
        }
        
        guard !emulatorCore.aspectSize().isEmpty() else {
            print("emulatorCore aspectSize is empty")
            return
        }
        
        let ratio: CGFloat = {
            let aspectSize = self.emulatorCore.aspectSize()
            if aspectSize.width > aspectSize.height {
                return aspectSize.width / aspectSize.height
            } else {
                return aspectSize.height / aspectSize.width
            }
        }()
        
        let parentSize: CGSize = {
            if let parentViewController = self.parentViewController {
                return parentViewController.view.bounds.size
            } else {
                return self.view.bounds.size
            }
        }()
        
        var height = CGFloat(0)
        var width = CGFloat(0)
        
        if parentSize.width > parentSize.height {
            height = parentSize.height
            width = CGFloat(roundf(Float(height)*Float(ratio)))
            
            if width > parentSize.width {
                width = parentSize.width
                height = CGFloat(roundf(Float(width)/Float(ratio)))
            }
        } else {
            width = parentSize.width;
            height = CGFloat(roundf(Float(width)/Float(ratio)))
            
            if (height > parentSize.height)
            {
                height = parentSize.width
                width = CGFloat(roundf(Float(height)/Float(ratio)))
            }
        }
        
        var origin = CGPoint(x: CGFloat(roundf((Float(parentSize.width) - Float(width)) / Float(2.0))), y: 0)
        if self.traitCollection.userInterfaceIdiom == .Phone && parentSize.height > parentSize.width {
            origin.y = CGFloat(roundf((Float(parentSize.height) - Float(height)) / Float(3.0))) // top 3rd of screen
        } else {
            origin.y = CGFloat(roundf((Float(parentSize.height) - Float(height)) / Float(2.0))) // centered
        }
        
        print("height is \(height), width is \(width), origin is \(origin)")
        
        self.view.frame = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        
    }
    
    func setupTexture() {
        glGenTextures(1, &self.texture)
        
        glBindTexture(UInt32(GL_TEXTURE_2D), texture)
        
        glTexImage2D(GLenum(GL_TEXTURE_2D),
            GLint(0),
            GLint(emulatorCore.internalPixelFormat()),
            GLsizei(self.emulatorCore.bufferSize().width),
            GLsizei(self.emulatorCore.bufferSize().height),
            GLint(0),
            GLenum(self.emulatorCore.pixelFormat()),
            GLenum(self.emulatorCore.pixelType()),
            self.emulatorCore.videoBuffer())
        
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MAG_FILTER), GLint(GL_NEAREST))
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MIN_FILTER), GLint(GL_NEAREST))
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_S), GLint(GL_CLAMP_TO_EDGE))
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_T), GLint(GL_CLAMP_TO_EDGE))
    }
    
    override func glkView(view: GLKView, drawInRect rect: CGRect) {
        let renderBlock: () -> () = {
            glClearColor(1.0, 1.0, 1.0, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            
            let screenSize = self.emulatorCore.screenRect().size
            let bufferSize = self.emulatorCore.bufferSize
            
            let texWidth: CGFloat = CGFloat(screenSize.width) / CGFloat(bufferSize().width)
            let texHeight: CGFloat = CGFloat(screenSize.height) / CGFloat(bufferSize().height)
            
            self.vertices = [GLKVector3Make(-1.0, -1.0,  1.0),
                GLKVector3Make( 1.0, -1.0,  1.0),
                GLKVector3Make( 1.0,  1.0,  1.0),
                GLKVector3Make(-1.0,  1.0,  1.0)]
            
            self.textureCoordinates = [
                GLKVector2Make(Float(0), Float(texHeight)),
                GLKVector2Make(Float(texWidth), Float(texHeight)),
                GLKVector2Make(Float(texWidth), Float(0.0)),
                GLKVector2Make(Float(CGFloat(0)), Float(0.0))]
            
            let vertexIndices: [Int] = [0, 1, 2, 0, 2, 3]
            
            self.triangleVertices = [
                self.vertices[vertexIndices[0]],
                self.vertices[vertexIndices[1]],
                self.vertices[vertexIndices[2]],
                self.vertices[vertexIndices[3]],
                self.vertices[vertexIndices[4]],
                self.vertices[vertexIndices[5]]
            ]
            
            self.triangleTexCoords = [
                self.textureCoordinates[vertexIndices[0]],
                self.textureCoordinates[vertexIndices[1]],
                self.textureCoordinates[vertexIndices[2]],
                self.textureCoordinates[vertexIndices[3]],
                self.textureCoordinates[vertexIndices[4]],
                self.textureCoordinates[vertexIndices[5]]
            ]
            
            glBindTexture(GLenum(GL_TEXTURE_2D), GLuint(self.texture))
            
            glTexSubImage2D(GLenum(GL_TEXTURE_2D),
                GLint(0),
                GLint(0),
                GLint(0),
                GLsizei(self.emulatorCore.bufferSize().width),
                GLsizei(self.emulatorCore.bufferSize().height),
                self.emulatorCore.pixelFormat(),
                self.emulatorCore.pixelType(),
                self.emulatorCore.videoBuffer())
            
            if !(self.texture == 0) {
                self.effect.texture2d0.envMode = .Replace
                self.effect.texture2d0.target = .Target2D
                self.effect.texture2d0.name = self.texture
                self.effect.texture2d0.enabled = GLboolean(GL_TRUE)
                self.effect.useConstantColor = GLboolean(GL_TRUE)
            }
            
            self.effect.prepareToDraw()
            
            glDisable(GLenum(GL_DEPTH_TEST))
            glDisable(GLenum(GL_CULL_FACE))
            
            glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))
            glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue),
                GLint(3),
                GLenum(GL_FLOAT),
                GLboolean(GL_FALSE),
                0,
                self.triangleVertices)
            
            if !(self.texture == 0) {
                glEnableVertexAttribArray(GLuint(GLKVertexAttrib.TexCoord0.rawValue));
                glVertexAttribPointer(GLuint(GLKVertexAttrib.TexCoord0.rawValue), GLint(2), GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, self.triangleTexCoords)
            }
            
            glDrawArrays(GLenum(GL_TRIANGLES), GLint(0), GLsizei(6))
            
            if !(self.texture == 0) {
                glDisableVertexAttribArray(GLuint(GLKVertexAttrib.TexCoord0.rawValue))
            }
            
            glDisableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))
        }
        
        if emulatorCore.fastForward {
            renderBlock()
        } else {
            let lockQueue = dispatch_queue_create("com.test.LockQueue", nil)
            dispatch_sync(lockQueue) {
                renderBlock()
            }
        }
    }
}










