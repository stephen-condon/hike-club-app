//
//  ZoomableImageView.swift
//  Pack134HikeClub
//
//  Full-screen, pinch/pan/double-tap zoomable viewer for the trail map image.
//  Native gestures come from UIScrollView (viewForZooming). Takes an already-loaded
//  UIImage from TrailInfoView, so it never touches the network — zooming can't fail
//  on an expired signed URL.
//

import SwiftUI
import UIKit

struct ZoomableImageView: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZoomableScrollView { UIImageView(image: image) }
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .padding()
                        .tint(.white)
                }
                Spacer()
            }
        }
    }
}

/// Wraps UIScrollView so pinch/pan/double-tap "just work" natively.
struct ZoomableScrollView: UIViewRepresentable {
    let makeImageView: () -> UIImageView

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4 // ponytail: fixed cap; make it fit-relative only if 4x proves too little
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black

        let imageView = makeImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = CGSize(width: scrollView.bounds.width / 2, height: scrollView.bounds.height / 2)
                let rect = CGRect(origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
                                  size: size)
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
