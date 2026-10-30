package com.midoreigh.mitra.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.midoreigh.mitra.miraie.MirAIeApi
import com.midoreigh.mitra.model.ACState
import com.midoreigh.mitra.store.ACStore
import com.midoreigh.mitra.store.Phase
import com.midoreigh.mitra.store.UiState
import kotlinx.coroutines.launch
import kotlin.math.roundToInt
import kotlin.math.sin

private val validColor = Color(0xFF4CD964)
private val warningColor = Color(0xFFFF9F0A)
private val errorColor = Color(0xFFFF6B60)

@Composable
fun SignInScreen(ui: UiState, store: ACStore) {
    var username by rememberSaveable { mutableStateOf(ui.lastUsername) }
    var password by rememberSaveable { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var working by remember { mutableStateOf(false) }
    /** Set once the user leaves the username field, so we don't nag while they type. */
    var usernameTouched by remember { mutableStateOf(false) }
    var usernameFocused by remember { mutableStateOf(false) }
    val passwordFocus = remember { FocusRequester() }
    val scope = rememberCoroutineScope()
    val shake = remember { Animatable(0f) }

    val identifier = MirAIeApi.loginIdentifier(username)
    val canSubmit = identifier != null && password.isNotEmpty() && !working
    val error = if (ui.phase == Phase.FAILED) ui.error else null

    LaunchedEffect(error) {
        if (error != null) {
            shake.snapTo(0f)
            shake.animateTo(1f, tween(400))
        }
    }

    fun submit() {
        usernameTouched = true
        if (!canSubmit) return
        working = true
        scope.launch {
            store.signIn(username, password)
            working = false
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(MitraColors.night)
            .verticalScroll(rememberScrollState())
            .imePadding()
            .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()),
    ) {
        GreetingHero()
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Welcome to Mitra for MirAIe", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
                Text("Use the same login as the MirAIe app.", color = MitraColors.secondaryText, fontSize = 15.sp)
            }

            Column(
                Modifier.offset { IntOffset((18 * sin(shake.value * Math.PI * 4)).roundToInt(), 0) },
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // What we understood from the username, or what's wrong with it.
                val (userColor, userMessage) = when {
                    error != null && identifier != null -> errorColor to "Check that this matches your MirAIe account."
                    identifier is MirAIeApi.LoginIdentifier.Mobile -> validColor to "Signing in as ${formatMobile(identifier.value)}"
                    identifier is MirAIeApi.LoginIdentifier.Email -> validColor to "Signing in as ${identifier.value}"
                    usernameTouched && username.isNotBlank() -> warningColor to problem(username)
                    else -> MitraColors.secondaryText to "Indian numbers don't need +91. Elsewhere, start with your country code, e.g. +44."
                }
                Field(
                    label = "Mobile number or email",
                    value = username,
                    onValueChange = { username = it; store.clearError() },
                    placeholder = "98765 43210",
                    accent = if (userColor == MitraColors.secondaryText) null else userColor,
                    message = userMessage,
                    messageColor = userColor,
                    valid = identifier != null && error == null,
                    keyboard = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                    actions = KeyboardActions(onNext = { usernameTouched = true; if (identifier != null) passwordFocus.requestFocus() }),
                    modifier = Modifier
                        .semantics { contentType = ContentType.Username }
                        .onFocusChanged {
                            if (usernameFocused && !it.isFocused && username.isNotEmpty()) usernameTouched = true
                            usernameFocused = it.isFocused
                        },
                )
                Field(
                    label = "Password",
                    value = password,
                    onValueChange = { password = it; store.clearError() },
                    placeholder = "MirAIe password",
                    accent = if (error != null) errorColor else null,
                    keyboard = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Go),
                    actions = KeyboardActions(onGo = { submit() }),
                    transformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                    trailing = {
                        IconButton(onClick = { showPassword = !showPassword }) {
                            Icon(
                                if (showPassword) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                if (showPassword) "Hide password" else "Show password",
                                tint = MitraColors.secondaryText,
                            )
                        }
                    },
                    modifier = Modifier.focusRequester(passwordFocus).semantics { contentType = ContentType.Password },
                )
            }

            AnimatedVisibility(error != null, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
                ErrorBanner(error ?: "")
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = ::submit,
                    enabled = canSubmit || working,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    shape = RoundedCornerShape(50),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = com.midoreigh.mitra.model.ACMode.COOL.controlTint,
                        contentColor = Color.White,
                        // A disabled button keeps its shape visible.
                        disabledContainerColor = com.midoreigh.mitra.model.ACMode.COOL.controlTint.copy(alpha = 0.4f),
                        disabledContentColor = Color.White.copy(alpha = 0.7f),
                    ),
                ) {
                    if (working) {
                        CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                    } else {
                        Text("Sign In", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Rounded.Lock, null, tint = MitraColors.secondaryText, modifier = Modifier.size(14.dp))
                    Text(
                        "Your password stays encrypted on this phone and is only sent to MirAIe.",
                        color = MitraColors.secondaryText, fontSize = 12.sp,
                    )
                }
            }

            TextButton(onClick = store::startDemo, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text("Try it without an account", color = com.midoreigh.mitra.model.ACMode.COOL.tint, fontSize = 15.sp)
            }
        }
    }
}

/** The control screen's hero, smaller: a running AC sweeping both ways, to greet the user. */
@Composable
private fun GreetingHero() {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val shape = RoundedCornerShape(bottomStart = 28.dp, bottomEnd = 28.dp)
    Box(Modifier.fillMaxWidth().height(top + 190.dp).clip(shape).border(1.dp, MitraColors.glassBorder, shape)) {
        GraphiteBackdrop(isOn = true, modifier = Modifier.fillMaxSize())
        ACUnitScene(
            remember { ACState(isOn = true) },
            Modifier.fillMaxSize().padding(start = 24.dp, end = 24.dp, top = top + 28.dp),
        )
    }
}

@Composable
private fun Field(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    accent: Color?,
    keyboard: KeyboardOptions,
    actions: KeyboardActions,
    modifier: Modifier = Modifier,
    message: String? = null,
    messageColor: Color = MitraColors.secondaryText,
    valid: Boolean = false,
    transformation: VisualTransformation = VisualTransformation.None,
    trailing: (@Composable () -> Unit)? = null,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Medium)
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = modifier.fillMaxWidth(),
            placeholder = { Text(placeholder, color = Color.White.copy(alpha = 0.35f)) },
            singleLine = true,
            keyboardOptions = keyboard,
            keyboardActions = actions,
            visualTransformation = transformation,
            shape = RoundedCornerShape(12.dp),
            trailingIcon = trailing ?: if (valid) {
                { Icon(Icons.Rounded.CheckCircle, null, tint = validColor) }
            } else null,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = accent ?: com.midoreigh.mitra.model.ACMode.COOL.tint,
                unfocusedBorderColor = accent ?: Color.White.copy(alpha = 0.16f),
                focusedContainerColor = Color.White.copy(alpha = 0.06f),
                unfocusedContainerColor = Color.White.copy(alpha = 0.06f),
                cursorColor = com.midoreigh.mitra.model.ACMode.COOL.tint,
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
            ),
        )
        if (message != null) Text(message, color = messageColor, fontSize = 12.sp)
    }
}

/** Why sign-in failed, in a red callout. */
@Composable
private fun ErrorBanner(message: String) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .background(errorColor.copy(alpha = 0.12f), shape)
            .border(1.dp, errorColor.copy(alpha = 0.35f), shape)
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Rounded.Error, null, tint = errorColor, modifier = Modifier.size(18.dp))
        Text(message, color = errorColor, fontSize = 14.sp)
    }
}

private fun problem(username: String): String {
    val trimmed = username.trim()
    if ("@" in trimmed) return "That email address looks incomplete."
    val digits = trimmed.count(Char::isDigit)
    if (trimmed.any(Char::isLetter)) return "Enter a mobile number or a full email address."
    if (trimmed.startsWith("+")) return "Include the country code and number, e.g. +44 7700 900123."
    if (digits < 10) return "Mobile numbers have 10 digits; this has $digits."
    return "That's too many digits for an Indian number. Start with + for other countries."
}

/** "+919876543210" → "+91 98765 43210". */
private fun formatMobile(mobile: String): String {
    if (!mobile.startsWith("+91") || mobile.length != 13) return mobile
    val digits = mobile.drop(3)
    return "+91 ${digits.take(5)} ${digits.takeLast(5)}"
}
