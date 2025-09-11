package com.example.customkeyboard

import android.content.Context
import android.content.Intent
import android.graphics.ImageFormat
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.activity.ComponentActivity
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.AlertDialog
import androidx.compose.material.Button
import androidx.compose.material.IconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import com.google.zxing.BinaryBitmap
import com.google.zxing.MultiFormatReader
import com.google.zxing.NotFoundException
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.HybridBinarizer
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class IMEServiceLifecycleOwner(private val imeService: LifecycleInputMethodService) : androidx.lifecycle.LifecycleOwner {
    override val lifecycle: androidx.lifecycle.Lifecycle
        get() = imeService.lifecycle
}

class BarcodeAnalyzer(
    private val onBarcodeScanned: (String) -> Unit,
    private val threshold: Int = 3,
    private val frameWidth: Int,
    private val frameHeight: Int
) : ImageAnalysis.Analyzer {

    private val reader = MultiFormatReader()
    private val lock = Any()

    private val scanQueue: MutableList<String> = mutableListOf()

    @OptIn(ExperimentalGetImage::class)
    override fun analyze(imageProxy: ImageProxy) {
        try {
            imageProxy.image?.let {
                if ((it.format == ImageFormat.YUV_420_888
                            || it.format == ImageFormat.YUV_422_888
                            || it.format == ImageFormat.YUV_444_888)
                    && it.planes.size == 3) {

                    val luminanceData = getLuminancePlaneData(imageProxy)
                    val rotatedImage = RotatedImage(luminanceData, imageProxy.width, imageProxy.height)
                    rotateImageArray(rotatedImage, imageProxy.imageInfo.rotationDegrees)

                    // Ensure the frame fits within the image bounds
                    val frameWidthAdjusted = minOf(frameWidth, rotatedImage.width)
                    val frameHeightAdjusted = minOf(frameHeight, rotatedImage.height)

                    // Calculate the center of the image to position the frame
                    val centerX = maxOf(0, (rotatedImage.width - frameWidthAdjusted) / 2)
                    val centerY = maxOf(0, (rotatedImage.height - frameHeightAdjusted) / 2)

                    // Ensure we don't exceed the image boundaries
                    val rightEdge = centerX + frameWidthAdjusted
                    val bottomEdge = centerY + frameHeightAdjusted

                    if (rightEdge > rotatedImage.width || bottomEdge > rotatedImage.height) {
                        // Skip this frame if dimensions don't fit
                        imageProxy.close()
                        return
                    }

                    // Only scan within the frame area
                    val source = PlanarYUVLuminanceSource(
                        rotatedImage.byteArray,
                        rotatedImage.width,
                        rotatedImage.height,
                        centerX,
                        centerY,
                        frameWidthAdjusted,
                        frameHeightAdjusted,
                        false
                    )

                    val binaryBitmap = BinaryBitmap(HybridBinarizer(source))

                    try {
                        val result = reader.decodeWithState(binaryBitmap)

                        synchronized(lock) {
                            // Add result to queue
                            scanQueue.add(result.text)

                            if (scanQueue.size > threshold) {
                                scanQueue.removeAt(0)
                            }

                            // If we have reached the threshold and all entries are equal, trigger scan
                            if (scanQueue.size == threshold && scanQueue.all { it == scanQueue[0] }) {
                                onBarcodeScanned(result.text)
                                scanQueue.clear()
                            }
                        }
                    } catch (e: NotFoundException) {
                        // No barcode found
                    } finally {
                        reader.reset()
                    }
                }
            }
        } catch (e: IllegalStateException) {
            e.printStackTrace()
        } finally {
            imageProxy.close()
        }
    }

    private fun getLuminancePlaneData(image: ImageProxy): ByteArray {
        val plane = image.planes[0]
        val buf: ByteBuffer = plane.buffer
        val data = ByteArray(buf.remaining())
        buf.get(data)
        buf.rewind()
        val width = image.width
        val height = image.height
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride

        val cleanData = ByteArray(width * height)
        for (y in 0 until height) {
            for (x in 0 until width) {
                cleanData[y * width + x] = data[y * rowStride + x * pixelStride]
            }
        }
        return cleanData
    }

    private fun rotateImageArray(imageToRotate: RotatedImage, rotationDegrees: Int) {
        if (rotationDegrees == 0) return
        if (rotationDegrees % 90 != 0) return

        val width = imageToRotate.width
        val height = imageToRotate.height

        val rotatedData = ByteArray(imageToRotate.byteArray.size)
        for (y in 0 until height) {
            for (x in 0 until width) {
                when (rotationDegrees) {
                    90 -> rotatedData[x * height + height - y - 1] =
                        imageToRotate.byteArray[x + y * width]
                    180 -> rotatedData[width * (height - y - 1) + width - x - 1] =
                        imageToRotate.byteArray[x + y * width]
                    270 -> rotatedData[y + x * height] =
                        imageToRotate.byteArray[y * width + width - x - 1]
                }
            }
        }

        imageToRotate.byteArray = rotatedData

        if (rotationDegrees != 180) {
            imageToRotate.height = width
            imageToRotate.width = height
        }
    }
}

private data class RotatedImage(var byteArray: ByteArray, var width: Int, var height: Int)

@Composable
fun CameraScanner(
    onBarcodeScanned: (String) -> Unit,
    cameraWidth: Dp,
    cameraHeight: Dp,
    flashlightOn: Boolean
) {
    val context = LocalContext.current
    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }
    var showCenterLine by remember { mutableStateOf(false) }
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }
    DisposableEffect(Unit) {
        onDispose {
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll() // Unbind to release camera
            }, ContextCompat.getMainExecutor(context))
        }
    }

    // Get the lifecycle owner based on context type
    val lifecycleOwner = when (context) {
        is ComponentActivity -> context
        is LifecycleInputMethodService -> IMEServiceLifecycleOwner(context)
        else -> null
    }

    // Convert Dp to pixels for frame dimensions
    val displayMetrics = context.resources.displayMetrics
    val frameWidthPx = (cameraWidth.value * displayMetrics.density).toInt()
    val frameHeightPx = (cameraHeight.value * displayMetrics.density).toInt()

    LaunchedEffect(flashlightOn) {
        if (lifecycleOwner != null) {
            val cameraProvider = cameraProviderFuture.get()
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            try {
                val camera = cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector
                )
                camera.cameraControl.enableTorch(flashlightOn)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    // Reset center line when frame dimensions change
    LaunchedEffect(cameraWidth, cameraHeight) {
        showCenterLine = false
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Box(
            modifier = Modifier.fillMaxSize()
        ) {
            AndroidView(
                factory = { ctx ->
                    val previewView = androidx.camera.view.PreviewView(ctx)

                    cameraProviderFuture.addListener({
                        val cameraProvider = cameraProviderFuture.get()
                        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                        val preview = androidx.camera.core.Preview.Builder().build().also {
                            it.setSurfaceProvider(previewView.surfaceProvider)
                        }

                        val imageAnalyzer = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                            .also {
                                it.setAnalyzer(
                                    cameraExecutor,
                                    BarcodeAnalyzer(
                                        onBarcodeScanned = { barcode ->
                                            showCenterLine = true  // Move this UP so it always happens when barcode is detected
                                            onBarcodeScanned(barcode)
                                            val vibrator = ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                                vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
                                            } else {
                                                @Suppress("DEPRECATION")
                                                vibrator.vibrate(100)
                                            }
                                        },
                                        frameWidth = frameWidthPx,
                                        frameHeight = frameHeightPx
                                    )
                                )
                            }

                        try {
                            // Clear all previous bindings
                            cameraProvider.unbindAll()

                            // Check if the lifecycleOwner is available before binding
                            if (lifecycleOwner != null) {
                                val camera = cameraProvider.bindToLifecycle(
                                    lifecycleOwner,
                                    cameraSelector,
                                    preview,
                                    imageAnalyzer
                                )

                                // Auto-focus on the center of the preview
                                previewView.post {
                                    val meterFactory = previewView.meteringPointFactory
                                    val centerX = previewView.width / 2f
                                    val centerY = previewView.height / 2f
                                    val centerMeteringPoint = meterFactory.createPoint(centerX, centerY)

                                    val action = FocusMeteringAction.Builder(centerMeteringPoint).build()
                                    camera.cameraControl.startFocusAndMetering(action)
                                }

                                // Set torch state
                                camera.cameraControl.enableTorch(flashlightOn)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }

                    }, ContextCompat.getMainExecutor(ctx))

                    previewView
                },
                modifier = Modifier.fillMaxSize()
            )

            Canvas(
                modifier = Modifier.fillMaxSize()
            ) {
                val dimColor = Color.Black.copy(alpha = 0.8f)
                drawRect(color = dimColor)

                val frameWidthPx = cameraWidth.toPx()
                val frameHeightPx = cameraHeight.toPx()
                val centerX = (size.width - frameWidthPx) / 2
                val centerY = (size.height - frameHeightPx) / 2

                // Draw the scanning frame (transparent area)
                drawRect(
                    color = Color.Transparent,
                    topLeft = Offset(centerX, centerY),
                    size = androidx.compose.ui.geometry.Size(frameWidthPx, frameHeightPx),
                    blendMode = BlendMode.Clear
                )

                // Draw frame border
                val borderColor = Color.White
                val borderWidth = 4f
                val cornerLength = 40f

                // Top-left corner
                drawLine(
                    color = borderColor,
                    start = Offset(centerX, centerY),
                    end = Offset(centerX + cornerLength, centerY),
                    strokeWidth = borderWidth
                )
                drawLine(
                    color = borderColor,
                    start = Offset(centerX, centerY),
                    end = Offset(centerX, centerY + cornerLength),
                    strokeWidth = borderWidth
                )

                // Top-right corner
                drawLine(
                    color = borderColor,
                    start = Offset(centerX + frameWidthPx, centerY),
                    end = Offset(centerX + frameWidthPx - cornerLength, centerY),
                    strokeWidth = borderWidth
                )
                drawLine(
                    color = borderColor,
                    start = Offset(centerX + frameWidthPx, centerY),
                    end = Offset(centerX + frameWidthPx, centerY + cornerLength),
                    strokeWidth = borderWidth
                )

                // Bottom-left corner
                drawLine(
                    color = borderColor,
                    start = Offset(centerX, centerY + frameHeightPx),
                    end = Offset(centerX + cornerLength, centerY + frameHeightPx),
                    strokeWidth = borderWidth
                )
                drawLine(
                    color = borderColor,
                    start = Offset(centerX, centerY + frameHeightPx),
                    end = Offset(centerX, centerY + frameHeightPx - cornerLength),
                    strokeWidth = borderWidth
                )

                // Bottom-right corner
                drawLine(
                    color = borderColor,
                    start = Offset(centerX + frameWidthPx, centerY + frameHeightPx),
                    end = Offset(centerX + frameWidthPx - cornerLength, centerY + frameHeightPx),
                    strokeWidth = borderWidth
                )
                drawLine(
                    color = borderColor,
                    start = Offset(centerX + frameWidthPx, centerY + frameHeightPx),
                    end = Offset(centerX + frameWidthPx, centerY + frameHeightPx - cornerLength),
                    strokeWidth = borderWidth
                )

                if (showCenterLine) {
                    val centerLineY = centerY + frameHeightPx / 2
                    drawLine(
                        color = Color.Green,
                        start = Offset(centerX, centerLineY),
                        end = Offset(centerX + frameWidthPx, centerLineY),
                        strokeWidth = 6f
                    )
                }
            }
        }
    }
}

@Composable
fun ScannerScreen(onClose: () -> Unit) {
    var isCameraActive by remember { mutableStateOf(true) }
    var cameraWidth by remember { mutableStateOf(330.dp) }
    var cameraHeight by remember { mutableStateOf(80.dp) }
    val context = LocalContext.current
    var flashlightOn by remember { mutableStateOf(false) }
    var isQrMode by remember { mutableStateOf(false) }
    var showErrorDialog by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf("") }

    if (showErrorDialog) {
        AlertDialog(
            onDismissRequest = { showErrorDialog = false },
            title = { Text("Error") },
            text = { Text(errorMessage) },
            confirmButton = {
                Button(onClick = { showErrorDialog = false }) {
                    Text("OK")
                }
            }
        )
    }

    Box(modifier = Modifier.fillMaxSize()) {
        if (isCameraActive) {
            CameraScanner(
                onBarcodeScanned = { barcodeValue ->
                    try {
                        if (barcodeValue.startsWith("http://") || barcodeValue.startsWith("https://")) {
                            val uri = barcodeValue.toUri()
                            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }

                            // Check if there's an activity that can handle this intent
                            if (intent.resolveActivity(context.packageManager) != null) {
                                context.startActivity(intent)
                            } else {
                                errorMessage = "No browser app found to open the link"
                                showErrorDialog = true
                            }
                        } else {
                            val intent = Intent().apply {
                                action = "com.example.customkeyboard.SCANNED_CODE"
                                putExtra("SCANNED_CODE", barcodeValue)
                            }
                            context.sendBroadcast(intent)
                            onClose()
                        }
                    } catch (e: Exception) {
                        errorMessage = "Error handling barcode: ${e.message}"
                        showErrorDialog = true
                    }
                },
                cameraWidth = cameraWidth,
                cameraHeight = cameraHeight,
                flashlightOn = flashlightOn
            )
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.TopEnd),
            contentAlignment = Alignment.TopEnd
        ) {
            IconButton(
                onClick = onClose,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    painter = painterResource(id = android.R.drawable.ic_menu_close_clear_cancel),
                    contentDescription = "Close Scanner",
                    tint = Color.White,
                    modifier = Modifier.size(40.dp)
                )
            }
        }

        // Foreground UI
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(26.dp)
        ) {
            Row(
                modifier = Modifier.padding(bottom = 20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    painter = painterResource(id = R.drawable.qrscanner),
                    contentDescription = null,
                    tint = Color.White
                )
                Text(
                    text = if (isQrMode) "Scan QR Code" else "Scan Barcode",
                    color = Color.White,
                    fontSize = 20.sp,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }

            Text(
                text = if (isQrMode)
                    "Place the QR code inside the square frame.\nEnsure it is centered and not blurry."
                else
                    "Place the barcode inside the rectangular frame.\nEnsure it is centered and not blurry.",
                color = Color.White,
                fontSize = 12.sp
            )

            Spacer(modifier = Modifier.weight(1f))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .border(2.dp, Color.White, RoundedCornerShape(8.dp))
                        .padding(4.dp)
                ) {
                    Icon(
                        painter = painterResource(id = if (isQrMode) R.drawable.qr_icon else R.drawable.barcode_icon),
                        contentDescription = if (isQrMode) "Switch to Barcode Mode" else "Switch to QR Code Mode",
                        tint = Color.White,
                        modifier = Modifier
                            .clickable {
                                isQrMode = !isQrMode
                                if (isQrMode) {
                                    cameraWidth = 250.dp
                                    cameraHeight = 250.dp
                                } else {
                                    cameraWidth = 330.dp
                                    cameraHeight = 80.dp
                                }
                            }
                            .size(40.dp)
                    )
                }

                Spacer(modifier = Modifier.width(16.dp))

                Box(
                    modifier = Modifier
                        .border(2.dp, Color.White, RoundedCornerShape(8.dp))
                        .padding(4.dp)
                ) {
                    Icon(
                        painter = painterResource(id = R.drawable.flash_icon),
                        contentDescription = if (flashlightOn) "Turn Flashlight Off" else "Turn Flashlight On",
                        tint = if (flashlightOn) Color.Yellow else Color.White,
                        modifier = Modifier
                            .clickable {
                                flashlightOn = !flashlightOn
                            }
                            .size(40.dp)
                    )
                }
            }
        }
    }
}