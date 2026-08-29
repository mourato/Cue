#if NOTINHAS_VIDEO_MODULE
//
    //  VideoEditorMotionSpring.swift
    //  Notinhas
//
    //  Damped spring integrator shared by the viewport timeline (Plan 110 / Screendrop parity).
//

    import Foundation

    struct VideoEditorSpringConstant: Sendable, Equatable {
        var tension: Double
        var friction: Double
        var inertia: Double
    }

    struct VideoEditorDampedSpring: Sendable {
        var position: Double
        var velocity: Double = 0

        mutating func snap(to value: Double) {
            position = value
            velocity = 0
        }

        mutating func step(toward target: Double, using constant: VideoEditorSpringConstant, dt: Double) {
            guard constant.inertia > 0 else {
                position = target
                velocity = 0
                return
            }
            let acceleration = (
                constant.tension * (target - position) - constant.friction * velocity,
            ) / constant.inertia
            velocity += acceleration * dt
            position += velocity * dt
        }
    }
#endif
