import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../../data/models/transcription_state.dart';
import '../providers/transcription_provider.dart';

class TranscriptionScreen extends ConsumerStatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  ConsumerState<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends ConsumerState<TranscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize model on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelStateProvider.notifier).initializeModel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(modelStateProvider);
    final transcriptionState = ref.watch(transcriptionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Transcription'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showModelSelector(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Model Status Card
              _buildModelStatusCard(modelState, theme),
              
              const SizedBox(height: 24),
              
              // Main Content Area
              Expanded(
                child: _buildContentArea(transcriptionState, theme),
              ),
              
              const SizedBox(height: 24),
              
              // Control Buttons
              _buildControlButtons(modelState, transcriptionState, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Build model status indicator card
  Widget _buildModelStatusCard(ModelState state, ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              state is ModelReady ? Icons.check_circle : Icons.info_outline,
              color: state is ModelReady 
                  ? theme.colorScheme.primary
                  : state is ModelError
                      ? theme.colorScheme.error
                      : theme.colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model Status',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getModelStatusText(state),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (state is ModelInitializing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  /// Build main content area based on transcription state
  Widget _buildContentArea(TranscriptionState state, ThemeData theme) {
    return switch (state) {
      TranscriptionIdle() => _buildIdleView(theme),
      TranscriptionRecording(:final duration) => _buildRecordingView(duration, theme),
      TranscriptionProcessing() => _buildProcessingView(theme),
      TranscriptionCompleted(:final text, :final processingTime) => 
        _buildResultView(text, processingTime, theme),
      TranscriptionError(:final message) => _buildErrorView(message, theme),
    };
  }

  /// Idle state view
  Widget _buildIdleView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Press the microphone button\nto start recording',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// Recording state view
  Widget _buildRecordingView(Duration duration, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.2),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Icon(
                  Icons.mic,
                  size: 80,
                  color: theme.colorScheme.error,
                ),
              );
            },
            onEnd: () {
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Recording...',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(duration),
            style: theme.textTheme.displaySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  /// Processing state view
  Widget _buildProcessingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Transcribing audio...',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// Result view
  Widget _buildResultView(String text, Duration processingTime, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transcription Result',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Processed in ${processingTime.inSeconds}s',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            elevation: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                text,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  _showSnackBar('Copied to clipboard', isError: false);
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ref.read(transcriptionProvider.notifier).reset();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('New Recording'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Error view
  Widget _buildErrorView(String message, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.read(transcriptionProvider.notifier).reset();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build control buttons
  Widget _buildControlButtons(
    ModelState modelState,
    TranscriptionState transcriptionState,
    ThemeData theme,
  ) {
    final isModelReady = modelState is ModelReady;
    final isRecording = transcriptionState is TranscriptionRecording;
    final isProcessing = transcriptionState is TranscriptionProcessing;
    final isDisabled = !isModelReady || isProcessing;

    if (isRecording) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(transcriptionProvider.notifier).cancelRecording();
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () {
                ref.read(transcriptionProvider.notifier).stopRecordingAndTranscribe();
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.stop),
              label: const Text('Stop & Transcribe'),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isDisabled
            ? null
            : () {
                ref.read(transcriptionProvider.notifier).startRecording();
              },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.mic),
        label: Text(isDisabled ? 'Initializing...' : 'Start Recording'),
      ),
    );
  }

  /// Show model selector dialog
  void _showModelSelector(BuildContext context) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModelOption(WhisperModel.tiny, 'Tiny', '75 MB', 'Fastest', theme),
            // _buildModelOption(WhisperModel.base, 'Base', '142 MB', 'Balanced', theme),
            // _buildModelOption(WhisperModel.small, 'Small', '466 MB', 'Most Accurate', theme),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build model option tile
  Widget _buildModelOption(
    WhisperModel model,
    String name,
    String size,
    String description,
    ThemeData theme,
  ) {
    return ListTile(
      title: Text(name),
      subtitle: Text('$size - $description'),
      onTap: () {
        ref.read(modelStateProvider.notifier).changeModel(model);
        Navigator.pop(context);
        _showSnackBar('Switching to $name model...', isError: false);
      },
    );
  }

  /// Show snackbar
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Get model status text
  String _getModelStatusText(ModelState state) {
    return switch (state) {
      ModelUninitialized() => 'Not initialized',
      ModelInitializing(:final modelName) => 'Loading $modelName...',
      ModelReady(:final modelName) => 'Ready ($modelName)',
      ModelError(:final message) => 'Error: $message',
    };
  }

  /// Format duration as MM:SS
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
